/* A pure C API to enable client code to embed GCC as a JIT-compiler.
   Copyright (C) 2013-2023 Free Software Foundation, Inc.

This file is part of GCC.

GCC is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3, or (at your option)
any later version.

GCC is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
General Public License for more details.

You should have received a copy of the GNU General Public License
along with GCC; see the file COPYING3.  If not see
<http://www.gnu.org/licenses/>.  */
package gccjit

import "core:c"
import "core:os/os2"

gcc_jit_context       :: struct {}
gcc_jit_result        :: struct {}
gcc_jit_object        :: struct {}
gcc_jit_location      :: struct {}
gcc_jit_type          :: struct {}
gcc_jit_field         :: struct {}
gcc_jit_struct        :: struct {}
gcc_jit_function_type :: struct {}
gcc_jit_vector_type   :: struct {}
gcc_jit_function      :: struct {}
gcc_jit_block         :: struct {}
gcc_jit_rvalue        :: struct {}
gcc_jit_lvalue        :: struct {}
gcc_jit_param         :: struct {}
gcc_jit_case          :: struct {}
gcc_jit_extended_asm  :: struct {}

when ODIN_OS == .Windows do foreign import lib "libgccjit.dll.a"

@(default_calling_convention="c")
foreign lib {
	/* Acquire a JIT-compilation context.  */
	gcc_jit_context_acquire :: proc() -> ^gcc_jit_context ---

	/* Release the context.  After this call, it's no longer valid to use
	the ctxt.  */
	gcc_jit_context_release :: proc(ctxt: ^gcc_jit_context) ---
}

/* Options taking string values. */
gcc_jit_str_option :: enum i32 {
	/* The name of the program, for use as a prefix when printing error
	messages to stderr.  If NULL, or default, "libgccjit.so" is used.  */
	STR_OPTION_PROGNAME = 0,
	NUM_STR_OPTIONS     = 1,
}

/* Options taking int values. */
gcc_jit_int_option :: enum i32 {
	/* How much to optimize the code.
	Valid values are 0-3, corresponding to GCC's command-line options
	-O0 through -O3.
	
	The default value is 0 (unoptimized).  */
	INT_OPTION_OPTIMIZATION_LEVEL = 0,
	NUM_INT_OPTIONS               = 1,
}

/* Options taking boolean values.
These all default to "false".  */
gcc_jit_bool_option :: enum i32 {
	/* If true, gcc_jit_context_compile will attempt to do the right
	thing so that if you attach a debugger to the process, it will
	be able to inspect variables and step through your code.
	
	Note that you can't step through code unless you set up source
	location information for the code (by creating and passing in
	gcc_jit_location instances).  */
	BOOL_OPTION_DEBUGINFO           = 0,

	/* If true, gcc_jit_context_compile will dump its initial "tree"
	representation of your code to stderr (before any
	optimizations).  */
	BOOL_OPTION_DUMP_INITIAL_TREE   = 1,

	/* If true, gcc_jit_context_compile will dump the "gimple"
	representation of your code to stderr, before any optimizations
	are performed.  The dump resembles C code.  */
	BOOL_OPTION_DUMP_INITIAL_GIMPLE = 2,

	/* If true, gcc_jit_context_compile will dump the final
	generated code to stderr, in the form of assembly language.  */
	BOOL_OPTION_DUMP_GENERATED_CODE = 3,

	/* If true, gcc_jit_context_compile will print information to stderr
	on the actions it is performing, followed by a profile showing
	the time taken and memory usage of each phase.
	*/
	BOOL_OPTION_DUMP_SUMMARY        = 4,

	/* If true, gcc_jit_context_compile will dump copious
	amount of information on what it's doing to various
	files within a temporary directory.  Use
	GCC_JIT_BOOL_OPTION_KEEP_INTERMEDIATES (see below) to
	see the results.  The files are intended to be human-readable,
	but the exact files and their formats are subject to change.
	*/
	BOOL_OPTION_DUMP_EVERYTHING     = 5,

	/* If true, libgccjit will aggressively run its garbage collector, to
	shake out bugs (greatly slowing down the compile).  This is likely
	to only be of interest to developers *of* the library.  It is
	used when running the selftest suite.  */
	BOOL_OPTION_SELFCHECK_GC        = 6,

	/* If true, gcc_jit_context_release will not clean up
	intermediate files written to the filesystem, and will display
	their location on stderr.  */
	BOOL_OPTION_KEEP_INTERMEDIATES  = 7,
	NUM_BOOL_OPTIONS                = 8,
}

@(default_calling_convention="c")
foreign lib {
	/* Set a string option on the given context.
	
	The context takes a copy of the string, so the
	(const char *) buffer is not needed anymore after the call
	returns.  */
	gcc_jit_context_set_str_option :: proc(ctxt: ^gcc_jit_context, opt: gcc_jit_str_option, value: cstring) ---

	/* Set an int option on the given context.  */
	gcc_jit_context_set_int_option :: proc(ctxt: ^gcc_jit_context, opt: gcc_jit_int_option, value: i32) ---

	/* Set a boolean option on the given context.
	
	Zero is "false" (the default), non-zero is "true".  */
	gcc_jit_context_set_bool_option :: proc(ctxt: ^gcc_jit_context, opt: gcc_jit_bool_option, value: i32) ---

	/* By default, libgccjit will issue an error about unreachable blocks
	within a function.
	
	This option can be used to disable that error.
	
	This entrypoint was added in LIBGCCJIT_ABI_2; you can test for
	its presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_context_set_bool_allow_unreachable_blocks
	*/
	gcc_jit_context_set_bool_allow_unreachable_blocks :: proc(ctxt: ^gcc_jit_context, bool_value: i32) ---

	/* By default, libgccjit will print errors to stderr.
	
	This option can be used to disable the printing.
	
	This entrypoint was added in LIBGCCJIT_ABI_23; you can test for
	its presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_context_set_bool_print_errors_to_stderr
	*/
	gcc_jit_context_set_bool_print_errors_to_stderr :: proc(ctxt: ^gcc_jit_context, enabled: i32) ---

	/* Implementation detail:
	libgccjit internally generates assembler, and uses "driver" code
	for converting it to other formats (e.g. shared libraries).
	
	By default, libgccjit will use an embedded copy of the driver
	code.
	
	This option can be used to instead invoke an external driver executable
	as a subprocess.
	
	This entrypoint was added in LIBGCCJIT_ABI_5; you can test for
	its presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_context_set_bool_use_external_driver
	*/
	gcc_jit_context_set_bool_use_external_driver :: proc(ctxt: ^gcc_jit_context, bool_value: i32) ---

	/* Add an arbitrary gcc command-line option to the context.
	The context takes a copy of the string, so the
	(const char *) optname is not needed anymore after the call
	returns.
	
	Note that only some options are likely to be meaningful; there is no
	"frontend" within libgccjit, so typically only those affecting
	optimization and code-generation are likely to be useful.
	
	This entrypoint was added in LIBGCCJIT_ABI_1; you can test for
	its presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_context_add_command_line_option
	*/
	gcc_jit_context_add_command_line_option :: proc(ctxt: ^gcc_jit_context, optname: cstring) ---

	/* Add an arbitrary gcc driver option to the context.
	The context takes a copy of the string, so the
	(const char *) optname is not needed anymore after the call
	returns.
	
	Note that only some options are likely to be meaningful; there is no
	"frontend" within libgccjit, so typically only those affecting
	assembler and linker are likely to be useful.
	
	This entrypoint was added in LIBGCCJIT_ABI_11; you can test for
	its presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_context_add_driver_option
	*/
	gcc_jit_context_add_driver_option :: proc(ctxt: ^gcc_jit_context, optname: cstring) ---

	/* Compile the context to in-memory machine code.
	
	This can be called more that once on a given context,
	although any errors that occur will block further compilation.  */
	gcc_jit_context_compile :: proc(ctxt: ^gcc_jit_context) -> ^gcc_jit_result ---
}

/* Kinds of ahead-of-time compilation, for use with
gcc_jit_context_compile_to_file.  */
gcc_jit_output_kind :: enum i32 {
	/* Compile the context to an assembler file.  */
	ASSEMBLER       = 0,

	/* Compile the context to an object file.  */
	OBJECT_FILE     = 1,

	/* Compile the context to a dynamic library.  */
	DYNAMIC_LIBRARY = 2,

	/* Compile the context to an executable.  */
	EXECUTABLE      = 3,
}

@(default_calling_convention="c")
foreign lib {
	/* Compile the context to a file of the given kind.
	
	This can be called more that once on a given context,
	although any errors that occur will block further compilation.  */
	gcc_jit_context_compile_to_file :: proc(ctxt: ^gcc_jit_context, output_kind: gcc_jit_output_kind, output_path: cstring) ---

	/* To help with debugging: dump a C-like representation to the given path,
	describing what's been set up on the context.
	
	If "update_locations" is true, then also set up gcc_jit_location
	information throughout the context, pointing at the dump file as if it
	were a source file.  This may be of use in conjunction with
	GCC_JIT_BOOL_OPTION_DEBUGINFO to allow stepping through the code in a
	debugger.  */
	gcc_jit_context_dump_to_file :: proc(ctxt: ^gcc_jit_context, path: cstring, update_locations: i32) ---

	/* To help with debugging; enable ongoing logging of the context's
	activity to the given FILE *.
	
	The caller remains responsible for closing "logfile".
	
	Params "flags" and "verbosity" are reserved for future use, and
	must both be 0 for now.  */
	//gcc_jit_context_set_logfile :: proc(ctxt: ^gcc_jit_context, logfile: ^FILE, flags: i32, verbosity: i32) ---
	gcc_jit_context_set_logfile :: proc(ctxt: ^gcc_jit_context, logfile: ^os2.File, flags: i32, verbosity: i32) ---

	/* To be called after any API call, this gives the first error message
	that occurred on the context.
	
	The returned string is valid for the rest of the lifetime of the
	context.
	
	If no errors occurred, this will be NULL.  */
	gcc_jit_context_get_first_error :: proc(ctxt: ^gcc_jit_context) -> cstring ---

	/* To be called after any API call, this gives the last error message
	that occurred on the context.
	
	If no errors occurred, this will be NULL.
	
	If non-NULL, the returned string is only guaranteed to be valid until
	the next call to libgccjit relating to this context. */
	gcc_jit_context_get_last_error :: proc(ctxt: ^gcc_jit_context) -> cstring ---

	/* Locate a given function within the built machine code.
	This will need to be cast to a function pointer of the
	correct type before it can be called. */
	gcc_jit_result_get_code :: proc(result: ^gcc_jit_result, funcname: cstring) -> rawptr ---

	/* Locate a given global within the built machine code.
	It must have been created using GCC_JIT_GLOBAL_EXPORTED.
	This is a ptr to the global, so e.g. for an int this is an int *.  */
	gcc_jit_result_get_global :: proc(result: ^gcc_jit_result, name: cstring) -> rawptr ---

	/* Once we're done with the code, this unloads the built .so file.
	This cleans up the result; after calling this, it's no longer
	valid to use the result.  */
	gcc_jit_result_release :: proc(result: ^gcc_jit_result) ---

	/**********************************************************************
	The base class of "contextual" object.
	**********************************************************************/
	/* Which context is "obj" within?  */
	gcc_jit_object_get_context :: proc(obj: ^gcc_jit_object) -> ^gcc_jit_context ---

	/* Get a human-readable description of this object.
	The string buffer is created the first time this is called on a given
	object, and persists until the object's context is released.  */
	gcc_jit_object_get_debug_string :: proc(obj: ^gcc_jit_object) -> cstring ---

	/* Creating source code locations for use by the debugger.
	Line and column numbers are 1-based.  */
	gcc_jit_context_new_location :: proc(ctxt: ^gcc_jit_context, filename: cstring, line: i32, column: i32) -> ^gcc_jit_location ---

	/* Upcasting from location to object.  */
	gcc_jit_location_as_object :: proc(loc: ^gcc_jit_location) -> ^gcc_jit_object ---

	/* Upcasting from type to object.  */
	gcc_jit_type_as_object :: proc(type: ^gcc_jit_type) -> ^gcc_jit_object ---
}

/* Access to specific types.  */
gcc_jit_types :: enum i32 {
	/* C's "void" type.  */
	VOID                = 0,

	/* "void *".  */
	VOID_PTR            = 1,

	/* C++'s bool type; also C99's "_Bool" type, aka "bool" if using
	stdbool.h.  */
	BOOL                = 2,

	/* Various integer types.  */
	
	/* C's "char" (of some signedness) and the variants where the
	signedness is specified.  */
	CHAR                = 3,
	SIGNED_CHAR         = 4,
	UNSIGNED_CHAR       = 5,

	/* C's "short" and "unsigned short".  */
	SHORT               = 6,  /* signed */
	UNSIGNED_SHORT      = 7,

	/* C's "int" and "unsigned int".  */
	INT                 = 8,  /* signed */
	UNSIGNED_INT        = 9,

	/* C's "long" and "unsigned long".  */
	LONG                = 10, /* signed */
	UNSIGNED_LONG       = 11,

	/* C99's "long long" and "unsigned long long".  */
	LONG_LONG           = 12, /* signed */
	UNSIGNED_LONG_LONG  = 13,

	/* Floating-point types  */
	FLOAT               = 14,
	DOUBLE              = 15,
	LONG_DOUBLE         = 16,

	/* C type: (const char *).  */
	CONST_CHAR_PTR      = 17,

	/* The C "size_t" type.  */
	SIZE_T              = 18,

	/* C type: (FILE *)  */
	FILE_PTR            = 19,

	/* Complex numbers.  */
	COMPLEX_FLOAT       = 20,
	COMPLEX_DOUBLE      = 21,
	COMPLEX_LONG_DOUBLE = 22,

	/* Sized integer types.  */
	UINT8_T             = 23,
	UINT16_T            = 24,
	UINT32_T            = 25,
	UINT64_T            = 26,
	UINT128_T           = 27,
	INT8_T              = 28,
	INT16_T             = 29,
	INT32_T             = 30,
	INT64_T             = 31,
	INT128_T            = 32,
}

@(default_calling_convention="c")
foreign lib {
	gcc_jit_context_get_type :: proc(ctxt: ^gcc_jit_context, type_: gcc_jit_types) -> ^gcc_jit_type ---

	/* Get the integer type of the given size and signedness.  */
	gcc_jit_context_get_int_type :: proc(ctxt: ^gcc_jit_context, num_bytes: i32, is_signed: i32) -> ^gcc_jit_type ---

	/* Given type "T", get type "T*".  */
	gcc_jit_type_get_pointer :: proc(type: ^gcc_jit_type) -> ^gcc_jit_type ---

	/* Given type "T", get type "const T".  */
	gcc_jit_type_get_const :: proc(type: ^gcc_jit_type) -> ^gcc_jit_type ---

	/* Given type "T", get type "volatile T".  */
	gcc_jit_type_get_volatile :: proc(type: ^gcc_jit_type) -> ^gcc_jit_type ---

	/* Given types LTYPE and RTYPE, return non-zero if they are compatible.
	This API entrypoint was added in LIBGCCJIT_ABI_20; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_SIZED_INTEGERS  */
	gcc_jit_compatible_types :: proc(ltype: ^gcc_jit_type, rtype: ^gcc_jit_type) -> i32 ---

	/* Given type "T", get its size.
	This API entrypoint was added in LIBGCCJIT_ABI_20; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_SIZED_INTEGERS  */
	gcc_jit_type_get_size :: proc(type: ^gcc_jit_type) -> i32 ---

	/* Given type "T", get type "T[N]" (for a constant N).  */
	gcc_jit_context_new_array_type :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, element_type: ^gcc_jit_type, num_elements: i32) -> ^gcc_jit_type ---

	/* Create a field, for use within a struct or union.  */
	gcc_jit_context_new_field :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, type: ^gcc_jit_type, name: cstring) -> ^gcc_jit_field ---

	/* Create a bit field, for use within a struct or union.
	
	This API entrypoint was added in LIBGCCJIT_ABI_12; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_context_new_bitfield
	*/
	gcc_jit_context_new_bitfield :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, type: ^gcc_jit_type, width: i32, name: cstring) -> ^gcc_jit_field ---

	/* Upcasting from field to object.  */
	gcc_jit_field_as_object :: proc(field: ^gcc_jit_field) -> ^gcc_jit_object ---

	/* Create a struct type from an array of fields.  */
	gcc_jit_context_new_struct_type :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, name: cstring, num_fields: i32, fields: ^^gcc_jit_field) -> ^gcc_jit_struct ---

	/* Create an opaque struct type.  */
	gcc_jit_context_new_opaque_struct :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, name: cstring) -> ^gcc_jit_struct ---

	/* Upcast a struct to a type.  */
	gcc_jit_struct_as_type :: proc(struct_type: ^gcc_jit_struct) -> ^gcc_jit_type ---

	/* Populating the fields of a formerly-opaque struct type.
	This can only be called once on a given struct type.  */
	gcc_jit_struct_set_fields :: proc(struct_type: ^gcc_jit_struct, loc: ^gcc_jit_location, num_fields: i32, fields: ^^gcc_jit_field) ---

	/* Get a field by index.  */
	gcc_jit_struct_get_field :: proc(struct_type: ^gcc_jit_struct, index: c.size_t) -> ^gcc_jit_field ---

	/* Get the number of fields.  */
	gcc_jit_struct_get_field_count :: proc(struct_type: ^gcc_jit_struct) -> c.size_t ---

	/* Unions work similarly to structs.  */
	gcc_jit_context_new_union_type :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, name: cstring, num_fields: i32, fields: ^^gcc_jit_field) -> ^gcc_jit_type ---

	/* Function pointers. */
	gcc_jit_context_new_function_ptr_type :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, return_type: ^gcc_jit_type, num_params: i32, param_types: ^^gcc_jit_type, is_variadic: i32) -> ^gcc_jit_type ---

	/**********************************************************************
	Constructing functions.
	**********************************************************************/
	/* Create a function param.  */
	gcc_jit_context_new_param :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, type: ^gcc_jit_type, name: cstring) -> ^gcc_jit_param ---

	/* Upcasting from param to object.  */
	gcc_jit_param_as_object :: proc(param: ^gcc_jit_param) -> ^gcc_jit_object ---

	/* Upcasting from param to lvalue.  */
	gcc_jit_param_as_lvalue :: proc(param: ^gcc_jit_param) -> ^gcc_jit_lvalue ---

	/* Upcasting from param to rvalue.  */
	gcc_jit_param_as_rvalue :: proc(param: ^gcc_jit_param) -> ^gcc_jit_rvalue ---
}

/* Kinds of function.  */
gcc_jit_function_kind :: enum i32 {
	/* Function is defined by the client code and visible
	by name outside of the JIT.  */
	EXPORTED      = 0,

	/* Function is defined by the client code, but is invisible
	outside of the JIT.  Analogous to a "static" function.  */
	INTERNAL      = 1,

	/* Function is not defined by the client code; we're merely
	referring to it.  Analogous to using an "extern" function from a
	header file.  */
	IMPORTED      = 2,

	/* Function is only ever inlined into other functions, and is
	invisible outside of the JIT.
	
	Analogous to prefixing with "inline" and adding
	__attribute__((always_inline)).
	
	Inlining will only occur when the optimization level is
	above 0; when optimization is off, this is essentially the
	same as GCC_JIT_FUNCTION_INTERNAL.  */
	ALWAYS_INLINE = 3,
}

/* Thread local storage model.  */
gcc_jit_tls_model :: enum i32 {
	NONE           = 0,
	GLOBAL_DYNAMIC = 1,
	LOCAL_DYNAMIC  = 2,
	INITIAL_EXEC   = 3,
	LOCAL_EXEC     = 4,
}

@(default_calling_convention="c")
foreign lib {
	/* Create a function.  */
	gcc_jit_context_new_function :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, kind: gcc_jit_function_kind, return_type: ^gcc_jit_type, name: cstring, num_params: i32, params: ^^gcc_jit_param, is_variadic: i32) -> ^gcc_jit_function ---

	/* Create a reference to a builtin function (sometimes called
	intrinsic functions).  */
	gcc_jit_context_get_builtin_function :: proc(ctxt: ^gcc_jit_context, name: cstring) -> ^gcc_jit_function ---

	/* Upcasting from function to object.  */
	gcc_jit_function_as_object :: proc(func: ^gcc_jit_function) -> ^gcc_jit_object ---

	/* Get a specific param of a function by index.  */
	gcc_jit_function_get_param :: proc(func: ^gcc_jit_function, index: i32) -> ^gcc_jit_param ---

	/* Emit the function in graphviz format.  */
	gcc_jit_function_dump_to_dot :: proc(func: ^gcc_jit_function, path: cstring) ---

	/* Create a block.
	
	The name can be NULL, or you can give it a meaningful name, which
	may show up in dumps of the internal representation, and in error
	messages.  */
	gcc_jit_function_new_block :: proc(func: ^gcc_jit_function, name: cstring) -> ^gcc_jit_block ---

	/* Upcasting from block to object.  */
	gcc_jit_block_as_object :: proc(block: ^gcc_jit_block) -> ^gcc_jit_object ---

	/* Which function is this block within?  */
	gcc_jit_block_get_function :: proc(block: ^gcc_jit_block) -> ^gcc_jit_function ---
}

/**********************************************************************
lvalues, rvalues and expressions.
**********************************************************************/
gcc_jit_global_kind :: enum i32 {
	/* Global is defined by the client code and visible
	by name outside of this JIT context via gcc_jit_result_get_global.  */
	EXPORTED = 0,

	/* Global is defined by the client code, but is invisible
	outside of this JIT context.  Analogous to a "static" global.  */
	INTERNAL = 1,

	/* Global is not defined by the client code; we're merely
	referring to it.  Analogous to using an "extern" global from a
	header file.  */
	IMPORTED = 2,
}

@(default_calling_convention="c")
foreign lib {
	gcc_jit_context_new_global :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, kind: gcc_jit_global_kind, type: ^gcc_jit_type, name: cstring) -> ^gcc_jit_lvalue ---

	/* Create a constructor for a struct as an rvalue.
	
	Returns NULL on error.  The two parameter arrays are copied and
	do not have to outlive the context.
	
	`type` specifies what the constructor will build and has to be
	a struct.
	
	`num_values` specifies the number of elements in `values`.
	
	`fields` need to have the same length as `values`, or be NULL.
	
	If `fields` is null, the values are applied in definition order.
	
	Otherwise, each field in `fields` specifies which field in the struct to
	set to the corresponding value in `values`.  `fields` and `values`
	are paired by index.
	
	Each value has to have the same unqualified type as the field
	it is applied to.
	
	A NULL value element  in `values` is a shorthand for zero initialization
	of the corresponding field.
	
	The fields in `fields` have to be in definition order, but there
	can be gaps.  Any field in the struct that is not specified in
	`fields` will be zeroed.
	
	The fields in `fields` need to be the same objects that were used
	to create the struct.
	
	If `num_values` is 0, the array parameters will be
	ignored and zero initialization will be used.
	
	The constructor rvalue can be used for assignment to locals.
	It can be used to initialize global variables with
	gcc_jit_global_set_initializer_rvalue.  It can also be used as a
	temporary value for function calls and return values.
	
	The constructor can contain nested constructors.
	
	This entrypoint was added in LIBGCCJIT_ABI_19; you can test for its
	presence using:
	#ifdef LIBGCCJIT_HAVE_CTORS
	*/
	gcc_jit_context_new_struct_constructor :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, type: ^gcc_jit_type, num_values: c.size_t, fields: ^^gcc_jit_field, values: ^^gcc_jit_rvalue) -> ^gcc_jit_rvalue ---

	/* Create a constructor for a union as an rvalue.
	
	Returns NULL on error.
	
	`type` specifies what the constructor will build and has to be
	an union.
	
	`field` specifies which field to set.  If it is NULL, the first
	field in the union will be set.  `field` need to be the same
	object that were used to create the union.
	
	`value` specifies what value to set the corresponding field to.
	If `value` is NULL, zero initialization will be used.
	
	Each value has to have the same unqualified type as the field
	it is applied to.
	
	`field` need to be the same objects that were used
	to create the union.
	
	The constructor rvalue can be used for assignment to locals.
	It can be used to initialize global variables with
	gcc_jit_global_set_initializer_rvalue.  It can also be used as a
	temporary value for function calls and return values.
	
	The constructor can contain nested constructors.
	
	This entrypoint was added in LIBGCCJIT_ABI_19; you can test for its
	presence using:
	#ifdef LIBGCCJIT_HAVE_CTORS
	*/
	gcc_jit_context_new_union_constructor :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, type: ^gcc_jit_type, field: ^gcc_jit_field, value: ^gcc_jit_rvalue) -> ^gcc_jit_rvalue ---

	/* Create a constructor for an array as an rvalue.
	
	Returns NULL on error.  `values` are copied and
	do not have to outlive the context.
	
	`type` specifies what the constructor will build and has to be
	an array.
	
	`num_values` specifies the number of elements in `values` and
	it can't have more elements than the array type.
	
	Each value in `values` sets the corresponding value in the array.
	If the array type itself has more elements than `values`, the
	left-over elements will be zeroed.
	
	Each value in `values` need to be the same unqualified type as the
	array type's element type.
	
	If `num_values` is 0, the `values` parameter will be
	ignored and zero initialization will be used.
	
	Note that a string literal rvalue can't be used to construct a char
	array.  It needs one rvalue for each char.
	
	This entrypoint was added in LIBGCCJIT_ABI_19; you can test for its
	presence using:
	#ifdef LIBGCCJIT_HAVE_CTORS
	*/
	gcc_jit_context_new_array_constructor :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, type: ^gcc_jit_type, num_values: c.size_t, values: ^^gcc_jit_rvalue) -> ^gcc_jit_rvalue ---

	/* Set the initial value of a global of any type with an rvalue.
	
	The rvalue needs to be a constant expression, e.g. no function calls.
	
	The global can't have the 'kind' GCC_JIT_GLOBAL_IMPORTED.
	
	Use together with gcc_jit_context_new_constructor () to
	initialize structs, unions and arrays.
	
	On success, returns the 'global' parameter unchanged.  Otherwise, NULL.
	
	'values' is copied and does not have to outlive the context.
	
	This entrypoint was added in LIBGCCJIT_ABI_19; you can test for its
	presence using:
	#ifdef LIBGCCJIT_HAVE_CTORS
	*/
	gcc_jit_global_set_initializer_rvalue :: proc(global: ^gcc_jit_lvalue, init_value: ^gcc_jit_rvalue) -> ^gcc_jit_lvalue ---

	/* Set an initial value for a global, which must be an array of
	integral type.  Return the global itself.
	
	This API entrypoint was added in LIBGCCJIT_ABI_14; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_global_set_initializer
	*/
	gcc_jit_global_set_initializer :: proc(global: ^gcc_jit_lvalue, blob: rawptr, num_bytes: c.size_t) -> ^gcc_jit_lvalue ---

	/* Upcasting.  */
	gcc_jit_lvalue_as_object :: proc(lvalue: ^gcc_jit_lvalue) -> ^gcc_jit_object ---
	gcc_jit_lvalue_as_rvalue :: proc(lvalue: ^gcc_jit_lvalue) -> ^gcc_jit_rvalue ---
	gcc_jit_rvalue_as_object :: proc(rvalue: ^gcc_jit_rvalue) -> ^gcc_jit_object ---
	gcc_jit_rvalue_get_type  :: proc(rvalue: ^gcc_jit_rvalue) -> ^gcc_jit_type ---

	/* Integer constants. */
	gcc_jit_context_new_rvalue_from_int  :: proc(ctxt: ^gcc_jit_context, numeric_type: ^gcc_jit_type, value: i32) -> ^gcc_jit_rvalue ---
	gcc_jit_context_new_rvalue_from_long :: proc(ctxt: ^gcc_jit_context, numeric_type: ^gcc_jit_type, value: c.long) -> ^gcc_jit_rvalue ---
	gcc_jit_context_zero                 :: proc(ctxt: ^gcc_jit_context, numeric_type: ^gcc_jit_type) -> ^gcc_jit_rvalue ---
	gcc_jit_context_one                  :: proc(ctxt: ^gcc_jit_context, numeric_type: ^gcc_jit_type) -> ^gcc_jit_rvalue ---

	/* Floating-point constants.  */
	gcc_jit_context_new_rvalue_from_double :: proc(ctxt: ^gcc_jit_context, numeric_type: ^gcc_jit_type, value: f64) -> ^gcc_jit_rvalue ---

	/* Pointers.  */
	gcc_jit_context_new_rvalue_from_ptr :: proc(ctxt: ^gcc_jit_context, pointer_type: ^gcc_jit_type, value: rawptr) -> ^gcc_jit_rvalue ---
	gcc_jit_context_null                :: proc(ctxt: ^gcc_jit_context, pointer_type: ^gcc_jit_type) -> ^gcc_jit_rvalue ---

	/* String literals. */
	gcc_jit_context_new_string_literal :: proc(ctxt: ^gcc_jit_context, value: cstring) -> ^gcc_jit_rvalue ---
}

gcc_jit_unary_op :: enum i32 {
	/* Negate an arithmetic value; analogous to:
	-(EXPR)
	in C.  */
	MINUS          = 0,

	/* Bitwise negation of an integer value (one's complement); analogous
	to:
	~(EXPR)
	in C.  */
	BITWISE_NEGATE = 1,

	/* Logical negation of an arithmetic or pointer value; analogous to:
	!(EXPR)
	in C.  */
	LOGICAL_NEGATE = 2,

	/* Absolute value of an arithmetic expression; analogous to:
	abs (EXPR)
	in C.  */
	ABS            = 3,
}

@(default_calling_convention="c")
foreign lib {
	gcc_jit_context_new_unary_op :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, op: gcc_jit_unary_op, result_type: ^gcc_jit_type, rvalue: ^gcc_jit_rvalue) -> ^gcc_jit_rvalue ---
}

gcc_jit_binary_op :: enum i32 {
	/* Addition of arithmetic values; analogous to:
	(EXPR_A) + (EXPR_B)
	in C.
	For pointer addition, use gcc_jit_context_new_array_access.  */
	PLUS        = 0,

	/* Subtraction of arithmetic values; analogous to:
	(EXPR_A) - (EXPR_B)
	in C.  */
	MINUS       = 1,

	/* Multiplication of a pair of arithmetic values; analogous to:
	(EXPR_A) * (EXPR_B)
	in C.  */
	MULT        = 2,

	/* Quotient of division of arithmetic values; analogous to:
	(EXPR_A) / (EXPR_B)
	in C.
	The result type affects the kind of division: if the result type is
	integer-based, then the result is truncated towards zero, whereas
	a floating-point result type indicates floating-point division.  */
	DIVIDE      = 3,

	/* Remainder of division of arithmetic values; analogous to:
	(EXPR_A) % (EXPR_B)
	in C.  */
	MODULO      = 4,

	/* Bitwise AND; analogous to:
	(EXPR_A) & (EXPR_B)
	in C.  */
	BITWISE_AND = 5,

	/* Bitwise exclusive OR; analogous to:
	(EXPR_A) ^ (EXPR_B)
	in C.  */
	BITWISE_XOR = 6,

	/* Bitwise inclusive OR; analogous to:
	(EXPR_A) | (EXPR_B)
	in C.  */
	BITWISE_OR  = 7,

	/* Logical AND; analogous to:
	(EXPR_A) && (EXPR_B)
	in C.  */
	LOGICAL_AND = 8,

	/* Logical OR; analogous to:
	(EXPR_A) || (EXPR_B)
	in C.  */
	LOGICAL_OR  = 9,

	/* Left shift; analogous to:
	(EXPR_A) << (EXPR_B)
	in C.  */
	LSHIFT      = 10,

	/* Right shift; analogous to:
	(EXPR_A) >> (EXPR_B)
	in C.  */
	RSHIFT      = 11,
}

@(default_calling_convention="c")
foreign lib {
	gcc_jit_context_new_binary_op :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, op: gcc_jit_binary_op, result_type: ^gcc_jit_type, a: ^gcc_jit_rvalue, b: ^gcc_jit_rvalue) -> ^gcc_jit_rvalue ---
}

/* (Comparisons are treated as separate from "binary_op" to save
you having to specify the result_type).  */
gcc_jit_comparison :: enum i32 {
	/* (EXPR_A) == (EXPR_B).  */
	EQ = 0,

	/* (EXPR_A) != (EXPR_B).  */
	NE = 1,

	/* (EXPR_A) < (EXPR_B).  */
	LT = 2,

	/* (EXPR_A) <=(EXPR_B).  */
	LE = 3,

	/* (EXPR_A) > (EXPR_B).  */
	GT = 4,

	/* (EXPR_A) >= (EXPR_B).  */
	GE = 5,
}

@(default_calling_convention="c")
foreign lib {
	gcc_jit_context_new_comparison :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, op: gcc_jit_comparison, a: ^gcc_jit_rvalue, b: ^gcc_jit_rvalue) -> ^gcc_jit_rvalue ---

	/* Call of a specific function.  */
	gcc_jit_context_new_call :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, func: ^gcc_jit_function, numargs: i32, args: ^^gcc_jit_rvalue) -> ^gcc_jit_rvalue ---

	/* Call through a function pointer.  */
	gcc_jit_context_new_call_through_ptr :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, fn_ptr: ^gcc_jit_rvalue, numargs: i32, args: ^^gcc_jit_rvalue) -> ^gcc_jit_rvalue ---

	/* Type-coercion.
	
	Currently only a limited set of conversions are possible:
	int <-> float
	int <-> bool  */
	gcc_jit_context_new_cast :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, rvalue: ^gcc_jit_rvalue, type: ^gcc_jit_type) -> ^gcc_jit_rvalue ---

	/* Reinterpret a value as another type.
	
	The types must be of the same size.
	
	This API entrypoint was added in LIBGCCJIT_ABI_21; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_context_new_bitcast  */
	gcc_jit_context_new_bitcast :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, rvalue: ^gcc_jit_rvalue, type: ^gcc_jit_type) -> ^gcc_jit_rvalue ---

	/* Set the alignment of a variable.
	
	This API entrypoint was added in LIBGCCJIT_ABI_24; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_ALIGNMENT  */
	gcc_jit_lvalue_set_alignment :: proc(lvalue: ^gcc_jit_lvalue, bytes: u32) ---

	/* Get the alignment of a variable.
	
	This API entrypoint was added in LIBGCCJIT_ABI_24; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_ALIGNMENT  */
	gcc_jit_lvalue_get_alignment     :: proc(lvalue: ^gcc_jit_lvalue) -> u32 ---
	gcc_jit_context_new_array_access :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, ptr: ^gcc_jit_rvalue, index: ^gcc_jit_rvalue) -> ^gcc_jit_lvalue ---

	/* Accessing a field of an lvalue of struct type, analogous to:
	(EXPR).field = ...;
	in C.  */
	gcc_jit_lvalue_access_field :: proc(struct_or_union: ^gcc_jit_lvalue, loc: ^gcc_jit_location, field: ^gcc_jit_field) -> ^gcc_jit_lvalue ---

	/* Accessing a field of an rvalue of struct type, analogous to:
	(EXPR).field
	in C.  */
	gcc_jit_rvalue_access_field :: proc(struct_or_union: ^gcc_jit_rvalue, loc: ^gcc_jit_location, field: ^gcc_jit_field) -> ^gcc_jit_rvalue ---

	/* Accessing a field of an rvalue of pointer type, analogous to:
	(EXPR)->field
	in C, itself equivalent to (*EXPR).FIELD  */
	gcc_jit_rvalue_dereference_field :: proc(ptr: ^gcc_jit_rvalue, loc: ^gcc_jit_location, field: ^gcc_jit_field) -> ^gcc_jit_lvalue ---

	/* Dereferencing a pointer; analogous to:
	*(EXPR)
	*/
	gcc_jit_rvalue_dereference :: proc(rvalue: ^gcc_jit_rvalue, loc: ^gcc_jit_location) -> ^gcc_jit_lvalue ---

	/* Taking the address of an lvalue; analogous to:
	&(EXPR)
	in C.  */
	gcc_jit_lvalue_get_address :: proc(lvalue: ^gcc_jit_lvalue, loc: ^gcc_jit_location) -> ^gcc_jit_rvalue ---

	/* Set the thread-local storage model of a global variable
	
	This API entrypoint was added in LIBGCCJIT_ABI_17; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_lvalue_set_tls_model  */
	gcc_jit_lvalue_set_tls_model :: proc(lvalue: ^gcc_jit_lvalue, model: gcc_jit_tls_model) ---

	/* Set the link section of a global variable; analogous to:
	__attribute__((section(".section_name")))
	in C.
	
	This API entrypoint was added in LIBGCCJIT_ABI_18; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_lvalue_set_link_section
	*/
	gcc_jit_lvalue_set_link_section :: proc(lvalue: ^gcc_jit_lvalue, section_name: cstring) ---

	/* Make this variable a register variable and set its register name.
	
	This API entrypoint was added in LIBGCCJIT_ABI_22; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_lvalue_set_register_name
	*/
	gcc_jit_lvalue_set_register_name :: proc(lvalue: ^gcc_jit_lvalue, reg_name: cstring) ---
	gcc_jit_function_new_local       :: proc(func: ^gcc_jit_function, loc: ^gcc_jit_location, type: ^gcc_jit_type, name: cstring) -> ^gcc_jit_lvalue ---

	/* Add evaluation of an rvalue, discarding the result
	(e.g. a function call that "returns" void).
	
	This is equivalent to this C code:
	
	(void)expression;
	*/
	gcc_jit_block_add_eval :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location, rvalue: ^gcc_jit_rvalue) ---

	/* Add evaluation of an rvalue, assigning the result to the given
	lvalue.
	
	This is roughly equivalent to this C code:
	
	lvalue = rvalue;
	*/
	gcc_jit_block_add_assignment :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location, lvalue: ^gcc_jit_lvalue, rvalue: ^gcc_jit_rvalue) ---

	/* Add evaluation of an rvalue, using the result to modify an
	lvalue.
	
	This is analogous to "+=" and friends:
	
	lvalue += rvalue;
	lvalue *= rvalue;
	lvalue /= rvalue;
	etc  */
	gcc_jit_block_add_assignment_op :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location, lvalue: ^gcc_jit_lvalue, op: gcc_jit_binary_op, rvalue: ^gcc_jit_rvalue) ---

	/* Add a no-op textual comment to the internal representation of the
	code.  It will be optimized away, but will be visible in the dumps
	seen via
	GCC_JIT_BOOL_OPTION_DUMP_INITIAL_TREE
	and
	GCC_JIT_BOOL_OPTION_DUMP_INITIAL_GIMPLE,
	and thus may be of use when debugging how your project's internal
	representation gets converted to the libgccjit IR.  */
	gcc_jit_block_add_comment :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location, text: cstring) ---

	/* Terminate a block by adding evaluation of an rvalue, branching on the
	result to the appropriate successor block.
	
	This is roughly equivalent to this C code:
	
	if (boolval)
	goto on_true;
	else
	goto on_false;
	
	block, boolval, on_true, and on_false must be non-NULL.  */
	gcc_jit_block_end_with_conditional :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location, boolval: ^gcc_jit_rvalue, on_true: ^gcc_jit_block, on_false: ^gcc_jit_block) ---

	/* Terminate a block by adding a jump to the given target block.
	
	This is roughly equivalent to this C code:
	
	goto target;
	*/
	gcc_jit_block_end_with_jump :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location, target: ^gcc_jit_block) ---

	/* Terminate a block by adding evaluation of an rvalue, returning the value.
	
	This is roughly equivalent to this C code:
	
	return expression;
	*/
	gcc_jit_block_end_with_return :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location, rvalue: ^gcc_jit_rvalue) ---

	/* Terminate a block by adding a valueless return, for use within a function
	with "void" return type.
	
	This is equivalent to this C code:
	
	return;
	*/
	gcc_jit_block_end_with_void_return :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location) ---

	/* Create a new gcc_jit_case instance for use in a switch statement.
	min_value and max_value must be constants of integer type.
	
	This API entrypoint was added in LIBGCCJIT_ABI_3; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_SWITCH_STATEMENTS
	*/
	gcc_jit_context_new_case :: proc(ctxt: ^gcc_jit_context, min_value: ^gcc_jit_rvalue, max_value: ^gcc_jit_rvalue, dest_block: ^gcc_jit_block) -> ^gcc_jit_case ---

	/* Upcasting from case to object.
	
	This API entrypoint was added in LIBGCCJIT_ABI_3; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_SWITCH_STATEMENTS
	*/
	gcc_jit_case_as_object :: proc(case_: ^gcc_jit_case) -> ^gcc_jit_object ---

	/* Terminate a block by adding evalation of an rvalue, then performing
	a multiway branch.
	
	This is roughly equivalent to this C code:
	
	switch (expr)
	{
	default:
	goto default_block;
	
	case C0.min_value ... C0.max_value:
	goto C0.dest_block;
	
	case C1.min_value ... C1.max_value:
	goto C1.dest_block;
	
	...etc...
	
	case C[N - 1].min_value ... C[N - 1].max_value:
	goto C[N - 1].dest_block;
	}
	
	block, expr, default_block and cases must all be non-NULL.
	
	expr must be of the same integer type as all of the min_value
	and max_value within the cases.
	
	num_cases must be >= 0.
	
	The ranges of the cases must not overlap (or have duplicate
	values).
	
	This API entrypoint was added in LIBGCCJIT_ABI_3; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_SWITCH_STATEMENTS
	*/
	gcc_jit_block_end_with_switch :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location, expr: ^gcc_jit_rvalue, default_block: ^gcc_jit_block, num_cases: i32, cases: ^^gcc_jit_case) ---

	/* Given an existing JIT context, create a child context.
	
	The child inherits a copy of all option-settings from the parent.
	
	The child can reference objects created within the parent, but not
	vice-versa.
	
	The lifetime of the child context must be bounded by that of the
	parent: you should release a child context before releasing the parent
	context.
	
	If you use a function from a parent context within a child context,
	you have to compile the parent context before you can compile the
	child context, and the gcc_jit_result of the parent context must
	outlive the gcc_jit_result of the child context.
	
	This allows caching of shared initializations.  For example, you could
	create types and declarations of global functions in a parent context
	once within a process, and then create child contexts whenever a
	function or loop becomes hot. Each such child context can be used for
	JIT-compiling just one function or loop, but can reference types
	and helper functions created within the parent context.
	
	Contexts can be arbitrarily nested, provided the above rules are
	followed, but it's probably not worth going above 2 or 3 levels, and
	there will likely be a performance hit for such nesting.  */
	gcc_jit_context_new_child_context :: proc(parent_ctxt: ^gcc_jit_context) -> ^gcc_jit_context ---

	/* Write C source code into "path" that can be compiled into a
	self-contained executable (i.e. with libgccjit as the only dependency).
	The generated code will attempt to replay the API calls that have been
	made into the given context.
	
	This may be useful when debugging the library or client code, for
	reducing a complicated recipe for reproducing a bug into a simpler
	form.
	
	Typically you need to supply the option "-Wno-unused-variable" when
	compiling the generated file (since the result of each API call is
	assigned to a unique variable within the generated C source, and not
	all are necessarily then used).  */
	gcc_jit_context_dump_reproducer_to_file :: proc(ctxt: ^gcc_jit_context, path: cstring) ---

	/* Enable the dumping of a specific set of internal state from the
	compilation, capturing the result in-memory as a buffer.
	
	Parameter "dumpname" corresponds to the equivalent gcc command-line
	option, without the "-fdump-" prefix.
	For example, to get the equivalent of "-fdump-tree-vrp1", supply
	"tree-vrp1".
	The context directly stores the dumpname as a (const char *), so the
	passed string must outlive the context.
	
	gcc_jit_context_compile and gcc_jit_context_to_file
	will capture the dump as a dynamically-allocated buffer, writing
	it to ``*out_ptr``.
	
	The caller becomes responsible for calling
	free (*out_ptr)
	each time that gcc_jit_context_compile or gcc_jit_context_to_file
	are called.  *out_ptr will be written to, either with the address of a
	buffer, or with NULL if an error occurred.
	
	This API entrypoint is likely to be less stable than the others.
	In particular, both the precise dumpnames, and the format and content
	of the dumps are subject to change.
	
	It exists primarily for writing the library's own test suite.  */
	gcc_jit_context_enable_dump :: proc(ctxt: ^gcc_jit_context, dumpname: cstring, out_ptr: ^cstring) ---
}

gcc_jit_timer :: struct {}

@(default_calling_convention="c")
foreign lib {
	/* Create a gcc_jit_timer instance, and start timing.
	
	This API entrypoint was added in LIBGCCJIT_ABI_4; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_TIMING_API
	*/
	gcc_jit_timer_new :: proc() -> ^gcc_jit_timer ---

	/* Release a gcc_jit_timer instance.
	
	This API entrypoint was added in LIBGCCJIT_ABI_4; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_TIMING_API
	*/
	gcc_jit_timer_release :: proc(timer: ^gcc_jit_timer) ---

	/* Associate a gcc_jit_timer instance with a context.
	
	This API entrypoint was added in LIBGCCJIT_ABI_4; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_TIMING_API
	*/
	gcc_jit_context_set_timer :: proc(ctxt: ^gcc_jit_context, timer: ^gcc_jit_timer) ---

	/* Get the timer associated with a context (if any).
	
	This API entrypoint was added in LIBGCCJIT_ABI_4; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_TIMING_API
	*/
	gcc_jit_context_get_timer :: proc(ctxt: ^gcc_jit_context) -> ^gcc_jit_timer ---

	/* Push the given item onto the timing stack.
	
	This API entrypoint was added in LIBGCCJIT_ABI_4; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_TIMING_API
	*/
	gcc_jit_timer_push :: proc(timer: ^gcc_jit_timer, item_name: cstring) ---

	/* Pop the top item from the timing stack.
	
	This API entrypoint was added in LIBGCCJIT_ABI_4; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_TIMING_API
	*/
	gcc_jit_timer_pop :: proc(timer: ^gcc_jit_timer, item_name: cstring) ---

	/* Print timing information to the given stream about activity since
	the timer was started.
	
	This API entrypoint was added in LIBGCCJIT_ABI_4; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_TIMING_API
	*/
	//gcc_jit_timer_print :: proc(timer: ^gcc_jit_timer, f_out: ^FILE) ---
	gcc_jit_timer_print :: proc(timer: ^gcc_jit_timer, f_out: ^os2.File) ---

	/* Mark/clear a call as needing tail-call optimization.
	
	This API entrypoint was added in LIBGCCJIT_ABI_6; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_rvalue_set_bool_require_tail_call
	*/
	gcc_jit_rvalue_set_bool_require_tail_call :: proc(call: ^gcc_jit_rvalue, require_tail_call: i32) ---

	/* Given type "T", get type:
	
	T __attribute__ ((aligned (ALIGNMENT_IN_BYTES)))
	
	The alignment must be a power of two.
	
	This API entrypoint was added in LIBGCCJIT_ABI_7; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_type_get_aligned
	*/
	gcc_jit_type_get_aligned :: proc(type: ^gcc_jit_type, alignment_in_bytes: c.size_t) -> ^gcc_jit_type ---

	/* Given type "T", get type:
	
	T  __attribute__ ((vector_size (sizeof(T) * num_units))
	
	T must be integral/floating point; num_units must be a power of two.
	
	This API entrypoint was added in LIBGCCJIT_ABI_8; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_type_get_vector
	*/
	gcc_jit_type_get_vector :: proc(type: ^gcc_jit_type, num_units: c.size_t) -> ^gcc_jit_type ---

	/* Get the address of a function as an rvalue, of function pointer
	type.
	
	This API entrypoint was added in LIBGCCJIT_ABI_9; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_function_get_address
	*/
	gcc_jit_function_get_address :: proc(fn: ^gcc_jit_function, loc: ^gcc_jit_location) -> ^gcc_jit_rvalue ---

	/* Build a vector rvalue from an array of elements.
	
	"vec_type" should be a vector type, created using gcc_jit_type_get_vector.
	
	This API entrypoint was added in LIBGCCJIT_ABI_10; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_context_new_rvalue_from_vector
	*/
	gcc_jit_context_new_rvalue_from_vector :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, vec_type: ^gcc_jit_type, num_elements: c.size_t, elements: ^^gcc_jit_rvalue) -> ^gcc_jit_rvalue ---

	/* Functions to retrieve libgccjit version.
	Analogous to __GNUC__, __GNUC_MINOR__, __GNUC_PATCHLEVEL__ in C code.
	
	These API entrypoints were added in LIBGCCJIT_ABI_13; you can test for their
	presence using
	#ifdef LIBGCCJIT_HAVE_gcc_jit_version
	*/
	gcc_jit_version_major      :: proc() -> i32 ---
	gcc_jit_version_minor      :: proc() -> i32 ---
	gcc_jit_version_patchlevel :: proc() -> i32 ---

	/* Create a gcc_jit_extended_asm for an extended asm statement
	with no control flow (i.e. without the goto qualifier).
	
	The asm_template parameter  corresponds to the AssemblerTemplate
	within C's extended asm syntax.  It must be non-NULL.  */
	gcc_jit_block_add_extended_asm :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location, asm_template: cstring) -> ^gcc_jit_extended_asm ---

	/* Create a gcc_jit_extended_asm for an extended asm statement
	that may perform jumps, and use it to terminate the given block.
	This is equivalent to the "goto" qualifier in C's extended asm
	syntax.  */
	gcc_jit_block_end_with_extended_asm_goto :: proc(block: ^gcc_jit_block, loc: ^gcc_jit_location, asm_template: cstring, num_goto_blocks: i32, goto_blocks: ^^gcc_jit_block, fallthrough_block: ^gcc_jit_block) -> ^gcc_jit_extended_asm ---

	/* Upcasting from extended asm to object.  */
	gcc_jit_extended_asm_as_object :: proc(ext_asm: ^gcc_jit_extended_asm) -> ^gcc_jit_object ---

	/* Set whether the gcc_jit_extended_asm has side-effects, equivalent to
	the "volatile" qualifier in C's extended asm syntax.  */
	gcc_jit_extended_asm_set_volatile_flag :: proc(ext_asm: ^gcc_jit_extended_asm, flag: i32) ---

	/* Set the equivalent of the "inline" qualifier in C's extended asm
	syntax.  */
	gcc_jit_extended_asm_set_inline_flag :: proc(ext_asm: ^gcc_jit_extended_asm, flag: i32) ---

	/* Add an output operand to the extended asm statement.
	"asm_symbolic_name" can be NULL.
	"constraint" and "dest" must be non-NULL.
	This function can't be called on an "asm goto" as such instructions
	can't have outputs  */
	gcc_jit_extended_asm_add_output_operand :: proc(ext_asm: ^gcc_jit_extended_asm, asm_symbolic_name: cstring, constraint: cstring, dest: ^gcc_jit_lvalue) ---

	/* Add an input operand to the extended asm statement.
	"asm_symbolic_name" can be NULL.
	"constraint" and "src" must be non-NULL.  */
	gcc_jit_extended_asm_add_input_operand :: proc(ext_asm: ^gcc_jit_extended_asm, asm_symbolic_name: cstring, constraint: cstring, src: ^gcc_jit_rvalue) ---

	/* Add "victim" to the list of registers clobbered by the extended
	asm statement.  It must be non-NULL.  */
	gcc_jit_extended_asm_add_clobber :: proc(ext_asm: ^gcc_jit_extended_asm, victim: cstring) ---

	/* Add "asm_stmts", a set of top-level asm statements, analogous to
	those created by GCC's "basic" asm syntax in C at file scope.  */
	gcc_jit_context_add_top_level_asm :: proc(ctxt: ^gcc_jit_context, loc: ^gcc_jit_location, asm_stmts: cstring) ---

	/* Reflection functions to get the number of parameters, return type of
	a function and whether a type is a bool from the C API.
	
	This API entrypoint was added in LIBGCCJIT_ABI_16; you can test for its
	presence using
	#ifdef LIBGCCJIT_HAVE_REFLECTION
	*/
	/* Get the return type of a function.  */
	gcc_jit_function_get_return_type :: proc(func: ^gcc_jit_function) -> ^gcc_jit_type ---

	/* Get the number of params of a function.  */
	gcc_jit_function_get_param_count :: proc(func: ^gcc_jit_function) -> c.size_t ---

	/* Get the element type of an array type or NULL if it's not an array.  */
	gcc_jit_type_dyncast_array :: proc(type: ^gcc_jit_type) -> ^gcc_jit_type ---

	/* Return non-zero if the type is a bool.  */
	gcc_jit_type_is_bool :: proc(type: ^gcc_jit_type) -> i32 ---

	/* Return the function type if it is one or NULL.  */
	gcc_jit_type_dyncast_function_ptr_type :: proc(type: ^gcc_jit_type) -> ^gcc_jit_function_type ---

	/* Given a function type, return its return type.  */
	gcc_jit_function_type_get_return_type :: proc(function_type: ^gcc_jit_function_type) -> ^gcc_jit_type ---

	/* Given a function type, return its number of parameters.  */
	gcc_jit_function_type_get_param_count :: proc(function_type: ^gcc_jit_function_type) -> c.size_t ---

	/* Given a function type, return the type of the specified parameter.  */
	gcc_jit_function_type_get_param_type :: proc(function_type: ^gcc_jit_function_type, index: c.size_t) -> ^gcc_jit_type ---

	/* Return non-zero if the type is an integral.  */
	gcc_jit_type_is_integral :: proc(type: ^gcc_jit_type) -> i32 ---

	/* Return the type pointed by the pointer type or NULL if it's not a
	* pointer.  */
	gcc_jit_type_is_pointer :: proc(type: ^gcc_jit_type) -> ^gcc_jit_type ---

	/* Given a type, return a dynamic cast to a vector type or NULL.  */
	gcc_jit_type_dyncast_vector :: proc(type: ^gcc_jit_type) -> ^gcc_jit_vector_type ---

	/* Given a type, return a dynamic cast to a struct type or NULL.  */
	gcc_jit_type_is_struct :: proc(type: ^gcc_jit_type) -> ^gcc_jit_struct ---

	/* Given a vector type, return the number of units it contains.  */
	gcc_jit_vector_type_get_num_units :: proc(vector_type: ^gcc_jit_vector_type) -> c.size_t ---

	/* Given a vector type, return the type of its elements.  */
	gcc_jit_vector_type_get_element_type :: proc(vector_type: ^gcc_jit_vector_type) -> ^gcc_jit_type ---

	/* Given a type, return the unqualified type, removing "const", "volatile"
	* and alignment qualifiers.  */
	gcc_jit_type_unqualified :: proc(type: ^gcc_jit_type) -> ^gcc_jit_type ---
}

