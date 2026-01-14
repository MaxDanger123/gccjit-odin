package tut1

import "core:fmt"
import "core:os"
import "../gccjit"

fn_type :: proc(_: cstring) -> cstring

main :: proc() {
    ctxt: ^gccjit.gcc_jit_context;
    result: ^gccjit.gcc_jit_result;

    ctxt = gccjit.gcc_jit_context_acquire();
    if(ctxt == nil) {
        fmt.eprintln("NULL ctxt");
        os.exit(1);
    }

    gccjit.gcc_jit_context_set_bool_option(ctxt, 
        gccjit.gcc_jit_bool_option.BOOL_OPTION_DUMP_GENERATED_CODE, 0);

    create_code(ctxt);

    result = gccjit.gcc_jit_context_compile(ctxt);
    if(result == nil) {
        fmt.eprintln("NULL result");
        os.exit(1);
    }

    greet := cast(fn_type)gccjit.gcc_jit_result_get_code(result, "greet");
    if(greet == nil) {
        fmt.eprintln("NULL greet");
        os.exit(1);
    }

    greet("world");

    gccjit.gcc_jit_context_release(ctxt);
    gccjit.gcc_jit_result_release(result);
}

create_code :: proc(ctxt: ^gccjit.gcc_jit_context) {
    void_type := gccjit.gcc_jit_context_get_type(ctxt, gccjit.gcc_jit_types.VOID);
    const_char_ptr_type := gccjit.gcc_jit_context_get_type(ctxt, 
        gccjit.gcc_jit_types.CONST_CHAR_PTR);
    param_name := gccjit.gcc_jit_context_new_param(ctxt, nil, const_char_ptr_type, "name");
    func := gccjit.gcc_jit_context_new_function(ctxt, nil, 
        gccjit.gcc_jit_function_kind.EXPORTED, void_type, "greet", 1, &param_name, 0);

    param_format := gccjit.gcc_jit_context_new_param(ctxt, nil, const_char_ptr_type, "format");
    printf_func := gccjit.gcc_jit_context_new_function(ctxt, nil, 
        gccjit.gcc_jit_function_kind.IMPORTED, 
        gccjit.gcc_jit_context_get_type(ctxt, gccjit.gcc_jit_types.INT), 
        "printf", 1, &param_format, 1);

    args := [2]^gccjit.gcc_jit_rvalue{};
    args[0] = gccjit.gcc_jit_context_new_string_literal(ctxt, "hello %s\n");
    args[1] = gccjit.gcc_jit_param_as_rvalue(param_name);

    block := gccjit.gcc_jit_function_new_block(func, nil);

    gccjit.gcc_jit_block_add_eval(
        block, nil,
        gccjit.gcc_jit_context_new_call(ctxt, nil, printf_func, 2, 
            cast(^^gccjit.gcc_jit_rvalue)&args));

    gccjit.gcc_jit_block_end_with_void_return(block, nil);
}