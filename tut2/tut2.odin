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

    void_type := gcc_jit_context_get_type(ctxt, gcc_jit_types.VOID);
    const_char_ptr_type := gcc_jit_context_get_type(ctxt, 
        gcc_jit_types.CONST_CHAR_PTR);
    param_name := gcc_jit_context_new_param(ctxt, nil, const_char_ptr_type, "name");
    func := gcc_jit_context_new_function(ctxt, nil, 
        gcc_jit_function_kind.EXPORTED, void_type, "greet", 1, &param_name, 0);

    param_format := gcc_jit_context_new_param(ctxt, nil, const_char_ptr_type, "format");
    printf_func := gcc_jit_context_new_function(ctxt, nil, 
        gcc_jit_function_kind.IMPORTED, 
        gcc_jit_context_get_type(ctxt, gcc_jit_types.INT), 
        "printf", 1, &param_format, 1);

    args := [2]^gcc_jit_rvalue{};
    args[0] = gcc_jit_context_new_string_literal(ctxt, "hello %s\n");
    args[1] = gcc_jit_param_as_rvalue(param_name);

    block := gcc_jit_function_new_block(func, nil);

    gcc_jit_block_add_eval(
        block, nil,
        gcc_jit_context_new_call(ctxt, nil, printf_func, 2, 
            cast(^^gcc_jit_rvalue)&args));

    gcc_jit_block_end_with_void_return(block, nil);
}