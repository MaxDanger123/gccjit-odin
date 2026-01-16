package main

import "core:testing"
import "core:strings"
import "core:fmt"
import "core:os"
import "core:strconv"
import "../gccjit"

//loop_test_fn_type :: proc(_: int) -> int

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

//v := Vector2{1, 2}

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

get_function_name :: proc(filename: ^string) -> (string, bool) {
    pathsep := strings.last_index_byte(filename^, '/');
    if(pathsep != -1) {
        filename := filename[pathsep:9];
        pathsep = strings.last_index_byte(filename, '.');
        if(pathsep != -1) {
            filename := filename[0:pathsep];
            return filename, true;
        } else {
            return "", false;
        }
    } else {
        return "", false;
    }
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

test_script :: proc(scripts_dir: string, script_name: string, input: int, 
    expected_result: int) {
    
    // toyvm_compiled_function *compiled_fn;
    // toyvm_compiled_code code;
    // int compiled_result;

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

    // compiled_fn = toyvm_function_compile (fn);
    // CHECK_NON_NULL (compiled_fn);

    // code = (toyvm_compiled_code)compiled_fn->cf_code;
    // CHECK_NON_NULL (code);

    // compiled_result = code (input);
    // CHECK_VALUE (compiled_result, expected_result);

    // gcc_jit_result_release (compiled_fn->cf_jit_result);
    // free (compiled_fn);
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