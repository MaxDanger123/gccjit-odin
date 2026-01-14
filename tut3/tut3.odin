package main

import "core:fmt"
import "core:os"
import "../gccjit"

loop_test_fn_type :: proc(_: int) -> int

main :: proc() {
    using gccjit

    ctxt: ^gcc_jit_context;
    result: ^gcc_jit_result;

    ctxt = gcc_jit_context_acquire();
    if(ctxt == nil) {
        fmt.eprintln("NULL ctxt");
        os.exit(1);
    }

    gcc_jit_context_set_bool_option(ctxt, 
        gcc_jit_bool_option.BOOL_OPTION_DUMP_GENERATED_CODE, 0);
    // gcc_jit_context_set_bool_option(ctxt, 
    //     gcc_jit_bool_option.BOOL_OPTION_DUMP_INITIAL_GIMPLE, 1);
    // gcc_jit_context_set_bool_option(ctxt, 
    //     gcc_jit_bool_option.BOOL_OPTION_DUMP_GENERATED_CODE, 1);
    // gcc_jit_context_set_int_option(ctxt, 
    //     gcc_jit_int_option.INT_OPTION_OPTIMIZATION_LEVEL, 1);
        
    create_code(ctxt);

    defer {
        if(ctxt != nil) {
            gcc_jit_context_release(ctxt);
        }
        if(result != nil) {
            gcc_jit_result_release(result);
        }
    }

    result = gcc_jit_context_compile(ctxt);
    if(result == nil) {
        fmt.eprintln("NULL result");
        os.exit(1);
    }

    gcc_jit_context_release(ctxt);
    ctxt = nil;

    loop_test := cast(loop_test_fn_type)gcc_jit_result_get_code(result, "loop_test");
    if(loop_test == nil) {
        fmt.eprintln("NULL fn_ptr");
        os.exit(1);
    }

    val := loop_test(10);
    fmt.printfln("loop test returned: %d", val);
}

create_code :: proc(ctxt: ^gccjit.gcc_jit_context) {
    using gccjit

    the_type := gcc_jit_context_get_type(ctxt, gcc_jit_types.INT);
    return_type := the_type;

    n := gcc_jit_context_new_param(ctxt, nil, the_type, "n");
    params := [1]^gcc_jit_param{n};
    func := gcc_jit_context_new_function(ctxt, nil, gcc_jit_function_kind.EXPORTED,
        return_type, "loop_test", 1, cast(^^gcc_jit_param)&params, 0);

    i := gcc_jit_function_new_local(func, nil, the_type, "i");
    sum := gcc_jit_function_new_local(func, nil, the_type, "sum");

    b_initial := gcc_jit_function_new_block(func, "initial");
    b_loop_cond := gcc_jit_function_new_block(func, "loop_cond");
    b_loop_body := gcc_jit_function_new_block(func, "loop_body");
    b_after_loop := gcc_jit_function_new_block(func, "after_loop");

    gcc_jit_block_add_assignment(b_initial, nil, sum, gcc_jit_context_zero(ctxt, the_type));
    gcc_jit_block_add_assignment(b_initial, nil, i, gcc_jit_context_zero(ctxt, the_type));
    gcc_jit_block_end_with_jump(b_initial, nil, b_loop_cond);

    guard := gcc_jit_context_new_comparison(ctxt, nil, gcc_jit_comparison.GE, 
        gcc_jit_lvalue_as_rvalue(i), gcc_jit_param_as_rvalue(n));
    gcc_jit_block_end_with_conditional(b_loop_cond, nil, guard, b_after_loop, b_loop_body);

    gcc_jit_block_add_assignment_op(b_loop_body, nil, sum, gcc_jit_binary_op.PLUS,
        gcc_jit_context_new_binary_op(ctxt, nil, gcc_jit_binary_op.MULT, the_type, 
            gcc_jit_lvalue_as_rvalue(i), gcc_jit_lvalue_as_rvalue(i)));
    gcc_jit_block_add_assignment_op(b_loop_body, nil, i, gcc_jit_binary_op.PLUS,
        gcc_jit_context_one(ctxt, the_type));
    gcc_jit_block_end_with_jump(b_loop_body, nil, b_loop_cond);

    gcc_jit_block_end_with_return(b_after_loop, nil, gcc_jit_lvalue_as_rvalue(sum));
}