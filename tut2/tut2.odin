package main

import "core:fmt"
import "core:os"
import "../gccjit"

fn_type :: proc(_: int) -> int

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
    gcc_jit_context_set_bool_option(ctxt, 
        gcc_jit_bool_option.BOOL_OPTION_DUMP_INITIAL_GIMPLE, 1);
    gcc_jit_context_set_bool_option(ctxt, 
        gcc_jit_bool_option.BOOL_OPTION_DUMP_GENERATED_CODE, 1);
    gcc_jit_context_set_int_option(ctxt, 
        gcc_jit_int_option.INT_OPTION_OPTIMIZATION_LEVEL, 1);
        
    create_code(ctxt);

    result = gcc_jit_context_compile(ctxt);
    if(result == nil) {
        fmt.eprintln("NULL result");
        os.exit(1);
    }

    defer {
        if(ctxt != nil) {
            gcc_jit_context_release(ctxt);
        }
        if(result != nil) {
            gcc_jit_result_release(result);
        }
    }

    gcc_jit_context_release(ctxt);
    ctxt = nil;

    fn_ptr := gcc_jit_result_get_code(result, "square");
    if(fn_ptr == nil) {
        fmt.eprintln("NULL fn_ptr");
        os.exit(1);
    }

    square := cast(fn_type)fn_ptr;
    fmt.printfln("result: %d", square(5));
}

create_code :: proc(ctxt: ^gccjit.gcc_jit_context) {
    using gccjit

    int_type := gcc_jit_context_get_type(ctxt, gcc_jit_types.INT);
    obj := gcc_jit_type_as_object(int_type);
    fmt.printfln("obj: %s", gcc_jit_object_get_debug_string(obj));

    param_i := gcc_jit_context_new_param(ctxt, nil, int_type, "i");
    func := gcc_jit_context_new_function(ctxt, nil, 
        gcc_jit_function_kind.EXPORTED, int_type, "square", 1, &param_i, 0);
    
    block := gcc_jit_function_new_block(func, nil);

    expr := gcc_jit_context_new_binary_op(ctxt, nil, gcc_jit_binary_op.MULT, int_type,
        gcc_jit_param_as_rvalue(param_i), gcc_jit_param_as_rvalue(param_i));
    fmt.printfln("expr: %s", gcc_jit_object_get_debug_string(gcc_jit_rvalue_as_object(expr)));
    
    gcc_jit_block_end_with_return(block, nil, expr);
}