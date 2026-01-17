package main

import "core:testing"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:strconv"
import "../gccjit"

compiled_code :: proc(_: int) -> int

Opcode :: enum {
    /* Ops taking no operand.  */
    DUP,
    ROT,
    BINARY_ADD,
    BINARY_SUBTRACT,
    BINARY_MULT,
    BINARY_COMPARE_LT,
    RECURSE,
    RETURN,

    /* Ops taking an operand.  */
    PUSH_CONST,
    JUMP_ABS_IF_TRUE
}

first_unary_opcode :: Opcode.PUSH_CONST

opcode_names := [?]string {
    "DUP",
    "ROT",
    "BINARY_ADD",
    "BINARY_SUBTRACT",
    "BINARY_MULT",
    "BINARY_COMPARE_LT",
    "RECURSE",
    "RETURN",

    "PUSH_CONST",
    "JUMP_ABS_IF_TRUE",
}

op :: struct {
    code: Opcode,
    operand: int,
    linenum: int,
}

max_ops :: 64

function :: struct {
    filename: string,
    num_ops: int,
    ops: [max_ops]op,
}

max_stack_depth :: 8

frame :: struct {
    function: ^function,
    pc: int,
    stack: [max_stack_depth]int,
    cur_depth: int,
}

add_op :: proc(fn: ^function, opcode: Opcode, operand: int, linenum: int) {
    op := new(op);
    assert(fn.num_ops < max_ops);
    op = &fn.ops[fn.num_ops];
    fn.num_ops += 1;
    op.code = opcode;
    op.operand = operand;
    op.linenum = linenum;
}

add_unary_op :: proc(fn: ^function, opcode: Opcode, rest_of_line: string, linenum: int) {
    operand, _ := strconv.parse_int(rest_of_line);
    add_op(fn, opcode, operand, linenum);
}

get_function_name :: proc(filename: string) -> string {
    // Skip any path separators
    result := filename
    pathsep := strings.last_index_byte(result, '/')
    if pathsep >= 0 {
        result = result[pathsep + 1:]
    }
    
    // Truncate at first '.'
    dot_index := strings.index_byte(result, '.')
    if dot_index >= 0 {
        result = result[:dot_index]
    }
    
    // Return allocated copy
    //return strings.clone(result)
    return result;
}

line_matches :: proc(opcode: string, line: string) -> bool {
    if(strings.compare(opcode, line) == 0) {
        return true;
    }
    return false;
}

function_parse :: proc(filename: string) -> (^function, bool) {
    data, ok := os.read_entire_file(filename, context.allocator)
	if !ok {
		// could not read file
		return nil, false;
	}
	defer delete(data, context.allocator)

	it := string(data)
    linenum := 0;

	fn := new(function);
    fn.filename = filename;
    
    lines := strings.split_lines(it);
    defer delete(lines);
    //for line in strings.split_lines_iterator(&it) {
	for line in lines {
        // process line
        linenum += 1;

        if(len(line) == 0) {
            continue;
        }

        if(line[0] == '#') {
            continue;
        }

        if(line[0] == '\n') {
            continue;
        }

        if(line_matches("DUP", line)) {
            add_op(fn, .DUP, 0, linenum);
        }
        else if(line_matches("ROT", line)) {
            add_op(fn, .ROT, 0, linenum);
        }
        else if(line_matches("BINARY_ADD", line)) {
            add_op(fn, .BINARY_ADD, 0, linenum);
        }
        else if(line_matches("BINARY_SUBTRACT", line)) {
            add_op(fn, .BINARY_SUBTRACT, 0, linenum);
        }
        else if(line_matches("BINARY_MULT", line)) {
            add_op(fn, .BINARY_MULT, 0, linenum);
        }
        else if(line_matches("BINARY_COMPARE_LT", line)) {
            add_op(fn, .BINARY_COMPARE_LT, 0, linenum);
        }
        else if(line_matches("RECURSE", line)) {
            add_op(fn, .RECURSE, 0, linenum);
        }
        else if(line_matches("RETURN", line)) {
            add_op(fn, .RETURN, 0, linenum);
        } else if(strings.starts_with(line, "PUSH_CONST ")) {
            str_len := len("PUSH_CONST ");
            add_unary_op(fn, .PUSH_CONST, line[str_len:] , linenum);
        }
        else if(strings.starts_with(line, "JUMP_ABS_IF_TRUE ")) {
            str_len := len("JUMP_ABS_IF_TRUE ");
            add_unary_op(fn, .JUMP_ABS_IF_TRUE, line[str_len:] , linenum);
        }
        else {
            fmt.eprintfln("%s:%d: parse error", filename, linenum);
            return nil, false;
        }
	}

    return fn, true;
}

function_disassemble_op :: proc(fn: ^function, op: ^op,
                                index: int, out: os.Handle) {
    fmt.fprintf(out, "%s:%d: index %d: %s", fn.filename, op.linenum, 
                    index, opcode_names[op.code]);
    if(op.code >= first_unary_opcode) {
        fmt.fprintf(out, " %d", op.operand);
    }
    fmt.fprintf(out, "\n");
}

function_disassemble :: proc(fn: ^function, out: os.Handle) {
    for i in 0..=fn.num_ops {
        op := &fn.ops[i];
        function_disassemble_op(fn, op, i, out);
    }
}

frame_push :: proc(frame: ^frame, arg: int) {
    assert(frame.cur_depth < max_stack_depth);
    frame.stack[frame.cur_depth] = arg;
    frame.cur_depth += 1;
}

frame_pop :: proc(frame: ^frame) -> int {
    assert(frame.cur_depth > 0);
    frame.cur_depth -= 1;
    return frame.stack[frame.cur_depth];
}

frame_dump_stack :: proc(frame: ^frame, out: os.Handle) {
    fmt.fprintf(out, "stack:");
    for i in 0..=frame.cur_depth {
        fmt.fprintf(out, " %d", frame.stack[i]);
    }
    fmt.fprintf(out, "\n");
}

push_arg :: proc(frame: ^frame, arg: int) {
        frame_push(frame, arg);
}

pop_arg :: proc(frame: ^frame) -> int {
        return frame_pop(frame);
}

function_interpret :: proc(fn: ^function, arg: int, trace: ^os.Handle) -> int {
    frame := frame{};
    frame.function = fn;
    frame.pc = 0;
    frame.cur_depth = 0;

    push_arg(&frame, arg);

    for {
        op := new(op);
        x: int;
        y: int;
        assert(frame.pc < fn.num_ops);
        op = &fn.ops[frame.pc];
        frame.pc += 1;
    
        if(trace != nil) {
            frame_dump_stack(&frame, trace^);
            function_disassemble_op(fn, op, frame.pc, trace^);
        }

        switch op.code {
            case .DUP:
                x = pop_arg(&frame);
                push_arg(&frame, x);
                push_arg(&frame, x);
            case .ROT:
                y = pop_arg(&frame);
                x = pop_arg(&frame);
                push_arg(&frame, y);
                push_arg(&frame, x);
            case .BINARY_ADD:
                y = pop_arg(&frame);
                x = pop_arg(&frame);
                push_arg(&frame, (x+y));
            case .BINARY_SUBTRACT:
                y = pop_arg(&frame);
                x = pop_arg(&frame);
                push_arg(&frame, (x-y));
            case .BINARY_MULT:
                y = pop_arg(&frame);
                x = pop_arg(&frame);
                push_arg(&frame, (x*y));
            case .BINARY_COMPARE_LT:
                y = pop_arg(&frame);
                x = pop_arg(&frame);
                push_arg(&frame, cast(int)(x<y));
            case .RECURSE:
                x = pop_arg(&frame);
                x = function_interpret(fn, x, trace);
                push_arg(&frame, x);
            case .RETURN:
                return pop_arg(&frame);
            case .PUSH_CONST:
                push_arg(&frame, op.operand);
            case .JUMP_ABS_IF_TRUE:
                x = pop_arg(&frame);
                if(x != 0) {
                    frame.pc = op.operand;
                }
        }
    }
}

// --- JIT COMPILATION ---

compilation_state :: struct {
    ctxt: ^gccjit.gcc_jit_context,

    int_type: ^gccjit.gcc_jit_type,
    bool_type: ^gccjit.gcc_jit_type,
    stack_type: ^gccjit.gcc_jit_type,

    const_one: ^gccjit.gcc_jit_rvalue,

    fn: ^gccjit.gcc_jit_function,
    param_arg: ^gccjit.gcc_jit_param,
    stack: ^gccjit.gcc_jit_lvalue,
    stack_depth: ^gccjit.gcc_jit_lvalue,
    x: ^gccjit.gcc_jit_lvalue,
    y: ^gccjit.gcc_jit_lvalue,

    op_locs: [max_ops]^gccjit.gcc_jit_location,
    initial_block: ^gccjit.gcc_jit_block,
    op_blocks: [max_ops]^gccjit.gcc_jit_block
}

add_push :: proc(state: ^compilation_state, block: ^gccjit.gcc_jit_block,
    rvalue: ^gccjit.gcc_jit_rvalue, loc: ^gccjit.gcc_jit_location) {
    using gccjit
    // stack[stack_depth]
    stack_stack_depth := gcc_jit_context_new_array_access(state.ctxt, loc, 
        gcc_jit_lvalue_as_rvalue(state.stack), 
        gcc_jit_lvalue_as_rvalue(state.stack_depth));
    // stack[stack_depth] = RVALUE
    gcc_jit_block_add_assignment(block, loc, stack_stack_depth, rvalue);

    // stack_depth++
    gcc_jit_block_add_assignment_op(block, loc, state.stack_depth, 
        gcc_jit_binary_op.PLUS, state.const_one);
}

add_pop :: proc(state: ^compilation_state, block: ^gccjit.gcc_jit_block,
    lvalue: ^gccjit.gcc_jit_lvalue, loc: ^gccjit.gcc_jit_location) {
    using gccjit
    
    // --stack_depth
    gcc_jit_block_add_assignment_op(block, loc, state.stack_depth,
        gcc_jit_binary_op.MINUS, state.const_one);
    // stack[stack_depth]
    stack_stack_depth := gcc_jit_context_new_array_access(state.ctxt, loc, 
        gcc_jit_lvalue_as_rvalue(state.stack), 
        gcc_jit_lvalue_as_rvalue(state.stack_depth));
    // LVALUE = stack[stack_depth]
    gcc_jit_block_add_assignment(block, loc, lvalue, 
        gcc_jit_lvalue_as_rvalue(stack_stack_depth));
}

compiled_function :: struct {
    jit_result: gccjit.gcc_jit_result,
    code: compiled_code,
}

function_compile :: proc(fn: ^function) -> ^compiled_function {
    using gccjit

    state := compilation_state{};
    pc: int;
    funcname := get_function_name(fn.filename);
    //fmt.printfln("funcname = %s", funcname);

    state.ctxt = gcc_jit_context_acquire();

    gcc_jit_context_set_bool_option (state.ctxt,
				   gcc_jit_bool_option.BOOL_OPTION_DUMP_INITIAL_GIMPLE,
				   0);
    gcc_jit_context_set_bool_option (state.ctxt,
				   gcc_jit_bool_option.BOOL_OPTION_DUMP_GENERATED_CODE,
				   0);
    gcc_jit_context_set_int_option (state.ctxt,
				    gcc_jit_int_option.INT_OPTION_OPTIMIZATION_LEVEL,
				  3);
    gcc_jit_context_set_bool_option (state.ctxt,
				   gcc_jit_bool_option.BOOL_OPTION_KEEP_INTERMEDIATES,
				   0);
    gcc_jit_context_set_bool_option (state.ctxt,
				   gcc_jit_bool_option.BOOL_OPTION_DUMP_EVERYTHING,
				   0);
    gcc_jit_context_set_bool_option (state.ctxt,
				   gcc_jit_bool_option.BOOL_OPTION_DEBUGINFO,
				   1);

    // create types
    state.int_type = gcc_jit_context_get_type(state.ctxt, gcc_jit_types.INT);
    state.bool_type = gcc_jit_context_get_type(state.ctxt, gcc_jit_types.BOOL);
    state.stack_type = gcc_jit_context_new_array_type(state.ctxt, nil, state.int_type, 
        max_stack_depth);

    // the constant value 1
    state.const_one = gcc_jit_context_one(state.ctxt, state.int_type);

    // create locations
    for pc in 0..<fn.num_ops {
        op := &fn.ops[pc];
        
        state.op_locs[pc] = gcc_jit_context_new_location(state.ctxt, 
            strings.clone_to_cstring(fn.filename), 
            cast(i32)op.linenum, 0);
    }

    // creating the function
    state.param_arg = gcc_jit_context_new_param(state.ctxt, state.op_locs[0], 
        state.int_type, "arg");
    state.fn = gcc_jit_context_new_function(state.ctxt, state.op_locs[0],
        gcc_jit_function_kind.EXPORTED, state.int_type, 
        strings.clone_to_cstring(funcname), 1, &state.param_arg, 0);

    // create stack lvalues
    state.stack = gcc_jit_function_new_local(state.fn, nil, state.stack_type, "stack");
    state.stack_depth = gcc_jit_function_new_local(state.fn, nil, state.int_type, "stack_depth");
    state.x = gcc_jit_function_new_local(state.fn, nil, state.int_type, "x");
    state.y = gcc_jit_function_new_local(state.fn, nil, state.int_type, "y");

    /* 1st pass: create blocks, one per opcode. */

    /* We need an entry block to do one-time initialization, so create that
     first.  */

    state.initial_block = gcc_jit_function_new_block(state.fn, "initial");

    // create a block per operation
    for pc in 0..<fn.num_ops {
        instr := fmt.tprintf("instr%i", pc);
        state.op_blocks[pc] = gcc_jit_function_new_block(state.fn, 
            strings.clone_to_cstring(instr));
        
        // fmt.printfln("fn.num_ops = %d", fn.num_ops);
        // fmt.printfln("state.op_blocks[pc]: %s", 
        //     gcc_jit_object_get_debug_string(gcc_jit_block_as_object(state.op_blocks[pc])));
    }

    // populate the initial block

    // stack_depth = 0;
    gcc_jit_block_add_assignment(state.initial_block, state.op_locs[0], 
        state.stack_depth, gcc_jit_context_zero(state.ctxt, state.int_type));

    // PUSH(arg);
    add_push(&state, state.initial_block, 
        gcc_jit_param_as_rvalue(state.param_arg), state.op_locs[0]);

    //fmt.printfln("state.op_blocks[0] = %p", state.op_blocks[0]);
    // ...and jump to insn0
    gcc_jit_block_end_with_jump(state.initial_block, state.op_locs[0], state.op_blocks[0]);

    /// 2nd pass: fill in instructions
    for pc in 0..<fn.num_ops {
        loc := state.op_locs[pc];

        block := state.op_blocks[pc];
        next_block: ^gcc_jit_block = (pc < fn.num_ops ? state.op_blocks[pc+1] : nil);

        op := &fn.ops[pc];

        //helper "macros" (functions)
        x_equals_pop :: proc(state: ^compilation_state, block: ^gcc_jit_block, 
            loc: ^gcc_jit_location) {
            add_pop(state, block, state.x, loc);
        }

        y_equals_pop :: proc(state: ^compilation_state, block: ^gcc_jit_block, 
            loc: ^gcc_jit_location) {
            add_pop(state, block, state.y, loc);
        }

        push_rvalue :: proc(state: ^compilation_state, block: ^gcc_jit_block,
            rvalue: ^gccjit.gcc_jit_rvalue, loc: ^gcc_jit_location) {
                add_push(state, block, rvalue, loc);
        }

        push_x :: proc(state: ^compilation_state, block: ^gcc_jit_block,
            loc: ^gcc_jit_location) {
            push_rvalue(state, block, gcc_jit_lvalue_as_rvalue(state.x), loc);
        }

        push_y :: proc(state: ^compilation_state, block: ^gcc_jit_block,
            loc: ^gcc_jit_location) {
            push_rvalue(state, block, gcc_jit_lvalue_as_rvalue(state.y), loc);
        }

        // gcc_jit_block_add_comment(block, loc, 
        //     strings.clone_to_cstring(opcode_names[op.operand]));

        // handle the individual opcodes

        switch op.code {
            case .DUP:
                x_equals_pop(&state, block, loc);
                push_x(&state, block, loc);
                push_x(&state, block, loc);
            case .ROT:
                y_equals_pop(&state, block, loc);
                x_equals_pop(&state, block, loc);
                push_y(&state, block, loc);
                push_x(&state, block, loc);
            case .BINARY_ADD:
                y_equals_pop(&state, block, loc);
                x_equals_pop(&state, block, loc);
                push_rvalue(&state, block, 
                    gcc_jit_context_new_binary_op(
                        state.ctxt, loc, gcc_jit_binary_op.PLUS, state.int_type, 
                        gcc_jit_lvalue_as_rvalue(state.x), 
                        gcc_jit_lvalue_as_rvalue(state.y)), loc);
            case .BINARY_SUBTRACT:
                y_equals_pop(&state, block, loc);
                x_equals_pop(&state, block, loc);
                push_rvalue(&state, block, 
                    gcc_jit_context_new_binary_op(
                        state.ctxt, loc, gcc_jit_binary_op.MINUS, state.int_type, 
                        gcc_jit_lvalue_as_rvalue(state.x), 
                        gcc_jit_lvalue_as_rvalue(state.y)), loc);
            case .BINARY_MULT:
                y_equals_pop(&state, block, loc);
                x_equals_pop(&state, block, loc);
                push_rvalue(&state, block, 
                    gcc_jit_context_new_binary_op(
                        state.ctxt, loc, gcc_jit_binary_op.MULT, state.int_type, 
                        gcc_jit_lvalue_as_rvalue(state.x), 
                        gcc_jit_lvalue_as_rvalue(state.y)), loc);
            case .BINARY_COMPARE_LT:
                y_equals_pop(&state, block, loc);
                x_equals_pop(&state, block, loc);
                push_rvalue(&state, block, 
                    gcc_jit_context_new_cast(
                        state.ctxt, loc,
                        gcc_jit_context_new_comparison(
                            state.ctxt,
                            loc, gcc_jit_comparison.LT, 
                            gcc_jit_lvalue_as_rvalue(state.x), 
                            gcc_jit_lvalue_as_rvalue(state.y)), 
                        state.int_type), loc);
            case .RECURSE:
                x_equals_pop(&state, block, loc);
                arg := gcc_jit_lvalue_as_rvalue(state.x);
                push_rvalue(&state, block,
                    gcc_jit_context_new_call(state.ctxt, loc, state.fn, 1, &arg),
                    loc);
            case .RETURN:
                x_equals_pop(&state, block, loc);
                gcc_jit_block_end_with_return(block, loc, 
                    gcc_jit_lvalue_as_rvalue(state.x));
            case .PUSH_CONST:
                push_rvalue(&state, block,
                    gcc_jit_context_new_rvalue_from_int(
                        state.ctxt, state.int_type, cast(i32)op.operand),
                    loc);
            case .JUMP_ABS_IF_TRUE:
                x_equals_pop(&state, block, loc);
                gcc_jit_block_end_with_conditional(block, loc,
                    gcc_jit_context_new_cast(state.ctxt, loc,
                        gcc_jit_lvalue_as_rvalue(state.x), state.bool_type),
                state.op_blocks[op.operand], next_block);
        } // end of switch on opcode

        if(op.code != .JUMP_ABS_IF_TRUE && op.code != .RETURN) {
            gcc_jit_block_end_with_jump(block, loc, next_block);
        }
    } // end of loop on pc locations

    gcc_jit_context_set_bool_option (state.ctxt,
        gcc_jit_bool_option.BOOL_OPTION_DUMP_GENERATED_CODE, 0);
    /* We've now finished populating the context.  Compile it.  */
    jit_result := gcc_jit_context_compile(state.ctxt);
    gcc_jit_context_release(state.ctxt);

    result := new(compiled_function);
    result.jit_result = jit_result^;
    result.code = cast(compiled_code)gcc_jit_result_get_code(jit_result, 
        strings.clone_to_cstring(funcname));

    /* (this leaks "jit_result" and "funcname") */
    
    return result;
}

test_script :: proc(scripts_dir: string, script_name: string, input: int, 
    expected_result: int) {
    to_be_concat := [?]string{scripts_dir, script_name};
    script_path := strings.concatenate(to_be_concat[:]);

    fn, err := function_parse(script_path);
    defer free(fn);
    if(err) {
        fmt.eprintfln("function_parse succeded");
    } else {
        fmt.eprintfln("function_parse failed");
        os.exit(1);
    }

    //fmt.printf("before\n");
    interpreted_result := function_interpret(fn, input, nil/*&os.stdout*/);
    //fmt.printf("after\n");
    if(interpreted_result == expected_result) {
        fmt.printfln("actual: %d == expected: %d", interpreted_result, expected_result);
    } else {
        fmt.printfln("actual: %d == expected: %d", interpreted_result, expected_result);
        os.exit(1);
    }

    compiled_fn := function_compile(fn);
    defer free(compiled_fn);
    if(compiled_fn != nil) {
        fmt.printfln("function compiling succeeded (?)");
    } else {
        fmt.printfln("function compiling failed");
        os.exit(1);
    }

    code := cast(compiled_code)compiled_fn.code;
    // CHECK_NON_NULL (code);

    compiled_result := code(input);
    if(compiled_result == expected_result) {
        fmt.printfln("COMPILED actual: %d == expected: %d", compiled_result, expected_result);
    } else {
        fmt.printfln("COMPILED actual: %d == expected: %d", compiled_result, expected_result);
        os.exit(1);
    }

    //gccjit.gcc_jit_result_release(&compiled_fn.jit_result);
}

path_to_scripts :: ""

test_suite :: proc() {
    test_script(path_to_scripts, "factorial.toy", 10, 3628800);
    test_script(path_to_scripts, "fibonacci.toy", 10, 55);
}

main :: proc() {
    if(len(os.args) < 3) {
        test_suite();
    }

    if(len(os.args) != 3) {
        fmt.printfln("%s FILENAME INPUT: Parse and run a .toy file", os.args[0]);
        os.exit(1);
    }

    filename := os.args[1];
    fn, err := function_parse(filename);
    if(err) {
        os.exit(1);
    }

    // if(0) {
    //     function_disassemble(fn, os.stdout);
    // }

    arg, _ := strconv.parse_int(os.args[2]);
    interpreter_result := function_interpret(fn, arg, nil);
    fmt.printfln("interpreter result: %d");

    // /* JIT-compilation.  */
    // toyvm_compiled_function *compiled_fn = toyvm_function_compile (fn);

    // toyvm_compiled_code code = compiled_fn->cf_code;
    // printf ("compiler result: %d\n",
    //     code (atoi (argv[2])));

    // gcc_jit_result_release (compiled_fn->cf_jit_result);
    // free (compiled_fn);
        
    // ----------------------------------------------------------
    
    // using gccjit

    // ctxt: ^gcc_jit_context;
    // result: ^gcc_jit_result;

    // ctxt = gcc_jit_context_acquire();
    // if(ctxt == nil) {
    //     fmt.eprintln("NULL ctxt");
    //     os.exit(1);
    // }

    // gcc_jit_context_set_bool_option(ctxt, 
    //     gcc_jit_bool_option.BOOL_OPTION_DUMP_GENERATED_CODE, 0);
    // // gcc_jit_context_set_bool_option(ctxt, 
    // //     gcc_jit_bool_option.BOOL_OPTION_DUMP_INITIAL_GIMPLE, 1);
    // // gcc_jit_context_set_bool_option(ctxt, 
    // //     gcc_jit_bool_option.BOOL_OPTION_DUMP_GENERATED_CODE, 1);
    // // gcc_jit_context_set_int_option(ctxt, 
    // //     gcc_jit_int_option.INT_OPTION_OPTIMIZATION_LEVEL, 1);
        
    // create_code(ctxt);

    // defer {
    //     if(ctxt != nil) {
    //         gcc_jit_context_release(ctxt);
    //     }
    //     if(result != nil) {
    //         gcc_jit_result_release(result);
    //     }
    // }

    // result = gcc_jit_context_compile(ctxt);
    // if(result == nil) {
    //     fmt.eprintln("NULL result");
    //     os.exit(1);
    // }

    // gcc_jit_context_release(ctxt);
    // ctxt = nil;

    // loop_test := cast(loop_test_fn_type)gcc_jit_result_get_code(result, "loop_test");
    // if(loop_test == nil) {
    //     fmt.eprintln("NULL fn_ptr");
    //     os.exit(1);
    // }

    // val := loop_test(10);
    // fmt.printfln("loop test returned: %d", val);
}

// create_code :: proc(ctxt: ^gccjit.gcc_jit_context) {
//     using gccjit

//     the_type := gcc_jit_context_get_type(ctxt, gcc_jit_types.INT);
//     return_type := the_type;

//     n := gcc_jit_context_new_param(ctxt, nil, the_type, "n");
//     params := [1]^gcc_jit_param{n};
//     func := gcc_jit_context_new_function(ctxt, nil, gcc_jit_function_kind.EXPORTED,
//         return_type, "loop_test", 1, cast(^^gcc_jit_param)&params, 0);

//     i := gcc_jit_function_new_local(func, nil, the_type, "i");
//     sum := gcc_jit_function_new_local(func, nil, the_type, "sum");

//     b_initial := gcc_jit_function_new_block(func, "initial");
//     b_loop_cond := gcc_jit_function_new_block(func, "loop_cond");
//     b_loop_body := gcc_jit_function_new_block(func, "loop_body");
//     b_after_loop := gcc_jit_function_new_block(func, "after_loop");

//     gcc_jit_block_add_assignment(b_initial, nil, sum, gcc_jit_context_zero(ctxt, the_type));
//     gcc_jit_block_add_assignment(b_initial, nil, i, gcc_jit_context_zero(ctxt, the_type));
//     gcc_jit_block_end_with_jump(b_initial, nil, b_loop_cond);

//     guard := gcc_jit_context_new_comparison(ctxt, nil, gcc_jit_comparison.GE, 
//         gcc_jit_lvalue_as_rvalue(i), gcc_jit_param_as_rvalue(n));
//     gcc_jit_block_end_with_conditional(b_loop_cond, nil, guard, b_after_loop, b_loop_body);

//     gcc_jit_block_add_assignment_op(b_loop_body, nil, sum, gcc_jit_binary_op.PLUS,
//         gcc_jit_context_new_binary_op(ctxt, nil, gcc_jit_binary_op.MULT, the_type, 
//             gcc_jit_lvalue_as_rvalue(i), gcc_jit_lvalue_as_rvalue(i)));
//     gcc_jit_block_add_assignment_op(b_loop_body, nil, i, gcc_jit_binary_op.PLUS,
//         gcc_jit_context_one(ctxt, the_type));
//     gcc_jit_block_end_with_jump(b_loop_body, nil, b_loop_cond);

//     gcc_jit_block_end_with_return(b_after_loop, nil, gcc_jit_lvalue_as_rvalue(sum));
// }