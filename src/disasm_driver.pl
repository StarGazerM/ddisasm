:-module(disasm_driver,[disasm_binary/1]).


valid_option('-hints').
valid_option('-debug').
valid_option('-debug_all').
valid_option('-asm').
valid_option('-no_print').

sections([
		%	'.eh_frame',
		'.text',
		'.plt',
		'.init',
		'.fini']).
data_sections([
		     '.got',
		     '.plt.got',
		      '.got.plt',
		     '.data',
		     '.rodata']).

% the things that are ignored with the parameter -asm
:-dynamic asm_skip_function/1.
asm_skip_function('_start').
asm_skip_function('deregister_tm_clones').
asm_skip_function('register_tm_clones').
asm_skip_function('__do_global_dtors_aux').
asm_skip_function('frame_dummy').
asm_skip_function('__libc_csu_fini').
asm_skip_function('__libc_csu_init').
asm_skip_function('__clang_call_terminate').

asm_skip_section('.comment').
asm_skip_section('.plt').
asm_skip_section('.init').
asm_skip_section('.fini').
asm_skip_section('.got').
asm_skip_section('.plt.got').
asm_skip_section('.got.plt').

asm_skip_symbol('_IO_stdin_used').


disasm_binary([File|Args]):-
    maplist(save_option,Args),
    set_prolog_flag(print_write_options,[quoted(false)]),

    (option('-asm')->format('/*~n',[]);true),
    
    format('Decoding binary~n',[]),
    file_directory_name(File, Dir),
    atom_concat(Dir,'/dl_files',Dir2),
    (\+exists_directory(Dir2)->
	 make_directory(Dir2);true),
    decode_sections(File,Dir2),
    format('Calling souffle~n',[]),
    call_souffle(Dir2),
    (option('-no_print')->
	 true
     ;
     format('Collecting results and printing~n',[]),
     collect_results(Dir2,_Results),
     generate_hints(Dir),

     (option('-asm')->format('*/~n',[]);true),
     pretty_print_results,
     print_stats
    ).

:-dynamic option/1.


save_option(Arg):-
    valid_option(Arg),
    assert(option(Arg)).

decode_sections(File,Dir):-
    sections(Sections),
    data_sections(Data_sections),
    foldl(collect_section_args(' --sect '),Sections,[],Sect_args),
    foldl(collect_section_args(' --data_sect '),Data_sections,[],Data_sect_args),
    atomic_list_concat(Sect_args,Section_chain),
    atomic_list_concat(Data_sect_args,Data_section_chain),
    atomic_list_concat(['./souffle_disasm ',' --file ',File,
			' --dir ',Dir,'/',Section_chain,Data_section_chain],Cmd),
    format('#cmd: ~p~n',[Cmd]),
    shell(Cmd).

collect_section_args(Arg,Name,Acc_sec,Acc_sec2):-
    Acc_sec2=[Arg,Name|Acc_sec].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
call_souffle(Dir):-
    %souffle souffle_rules.pl -I ../examples/bzip/
    atomic_list_concat(['souffle ../src/datalog/souffle_rules.dl  -F ',Dir,' -D ',Dir,' -p ',Dir,'/profile'],Cmd),
    time(shell(Cmd)).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Pretty printer
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
result_descriptors([
			  result(symbol,5,'.facts'),
			  result(section,3,'.facts'),
			  result(instruction,6,'.facts'),
			  result(op_regdirect,2,'.facts'),
			  result(op_immediate,2,'.facts'),
			  result(op_indirect,8,'.facts'),
			  result(data_byte,2,'.facts'),

			  result(direct_jump,2,'.csv'),	
			%  result(reg_jump,1,'.csv'),
			%  result(indirect_jump,1,'.csv'),
			  result(pc_relative_jump,2,'.csv'),
			  
			  result(direct_call,2,'.csv'),
			%  result(reg_call,1,'.csv'),
			%  result(indirect_call,1,'.csv'),
			  result(pc_relative_call,2,'.csv'),

			  result(plt_reference,2,'.csv'),

			  %result(possible_target,'phase2-possible_target',1,'.csv'),
			  named_result(likely_ea,'likely_ea_final',2,'.csv'),
			  named_result(remaining_ea,'phase2-remaining_ea',1,'.csv'),
			  named_result(chunk_overlap,'chunk_overlap2',2,'.csv'),

			  result(function_symbol,2,'.csv'),
			  result(main_function,1,'.csv'),
			  result(ambiguous_symbol,1,'.csv'),
			  result(chunk_start,1,'.csv'),
			  result(discarded_chunk,1,'.csv'),

			  result(symbolic_operand,2,'.csv'),
			  result(labeled_data,1,'.csv'),
			  result(float_data,1,'.csv'),
			  result(symbolic_data,2,'.csv'),
			  result(string,2,'.csv'),

			  
			  result(bss_data,1,'.csv'),
			  result(preferred_label,2,'.csv'),
			  result(def_used,3,'.csv'),
			  result(data_access_pattern,4,'.csv'),
			  result(moved_label,4,'.csv'),
			  result(value_reg,7,'.csv')
		      ]).

:-dynamic symbol/5.
:-dynamic section/3.
:-dynamic instruction/6.
:-dynamic op_regdirect/2.
:-dynamic op_immediate/2.
:-dynamic op_indirect/8.
:-dynamic data_byte/2.


:-dynamic direct_jump/2.
:-dynamic reg_jump/1.
:-dynamic indirect_jump/1.
:-dynamic pc_relative_jump/2.


:-dynamic direct_call/2.
:-dynamic reg_call/1.
:-dynamic indirect_call/1.
:-dynamic pc_relative_call/2.
:-dynamic plt_reference/2.

:-dynamic likely_ea/2.
:-dynamic remaining_ea/1.
:-dynamic function_symbol/2.
:-dynamic main_function/1.
:-dynamic ambiguous_symbol/1.

:-dynamic chunk_start/1.
:-dynamic chunk_overlap/2.
:-dynamic discarded_chunk/1.

:-dynamic symbolic_operand/2.
:-dynamic labeled_data/1.
:-dynamic float_data/1.
:-dynamic symbolic_data/2.
:-dynamic string/2.

:-dynamic bss_data/1.


:-dynamic data_access_pattern/4.
:-dynamic preferred_label/2.
:-dynamic def_used/3.
:-dynamic value_reg/7.
:-dynamic moved_label/4.

collect_results(Dir,results(Results)):-
    result_descriptors(Descriptors),
    maplist(collect_result(Dir),Descriptors,Results).

collect_result(Dir,named_result(Name,Filename,Arity,Ending),Result):-
    atom_concat(Filename,Ending,Name_file),
    directory_file_path(Dir,Name_file,Path),
    csv_read_file(Path, Result, [functor(Name), arity(Arity),separator(0'\t)]),
    maplist(assertz,Result).

collect_result(Dir,result(Name,Arity,Ending),Result):-
    atom_concat(Name,Ending,Name_file),
    directory_file_path(Dir,Name_file,Path),
    csv_read_file(Path, Result, [functor(Name), arity(Arity),separator(0'\t)]),
    maplist(assertz,Result).



print_stats:-
    format('~n~n#Result statistics:~n',[]),
    result_descriptors(Descriptors),
    maplist(print_descriptor_stats,Descriptors).

print_descriptor_stats(Res):-
    (Res=result(Name,Arity,_)
     ;
     Res=named_result(Name,_,Arity,_)
    ),
    functor(Head,Name,Arity),
    findall(Head,Head,Results),
    length(Results,N),
    format(' # Number of ~p: ~p~n',[Name,N]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pretty_print_results:-
    print_header,
    get_chunks(Chunks),
    maplist(pp_chunk, Chunks),
    get_data(Data),
    split_rodata_and_data(Data,Rodata,RWdata),
    format('.section .rodata~n',[]),
    pp_aligned_data_section(Rodata),
    % maplist(pp_data,Data),
   % trace,
    format('.section .data~n',[]),
    pp_aligned_data_section(RWdata),
    
    get_bss_data(Uninitialized_data),
    %we want to make sure we don't mess up the alignment
    format('.bss~n .align 16~n',[]),
    maplist(pp_bss_data,Uninitialized_data).

split_rodata_and_data(Data,Rodata,Rwdata):-
    section('.rodata',SizeSect,Base),
    End is Base+SizeSect,
    split_data_in_ea(Data,End,Rodata,Rwdata).
split_rodata_and_data(Data,[],Data):-
    \+section('.rodata',_,_).

split_data_in_ea([],_,[],[]).
split_data_in_ea([Item|Data],EA,[Item|Rodata],Rwdata):-
    get_item_ea(Item,EA_item),
    EA_item<EA,
    split_data_in_ea(Data,EA,Rodata,Rwdata).
split_data_in_ea([Item|Data],EA,[],[Item|Data]):-
    get_item_ea(Item,EA_item),
    EA_item>=EA.

get_item_ea(data_group(EA,_,_),EA).
get_item_ea(data_byte(EA,_),EA).


pp_aligned_data_section(Data_list):-
    % get first aligned label
    nth0(Index,Data_list,data_group(EA,_Type,_Content)),
    Alignment is EA mod 16,!,
    
    
    split_at(Index,Data_list,Data_before,Data_after),
    maplist(pp_data,Data_before),
    format('.align 16~n',[]),
    format('# printing ~p extra bytes to guarantee alignment~n',[Alignment]),
    print_x_zeros(Alignment),
    maplist(pp_data,Data_after).

%if there are no aligned labels
pp_aligned_data_section(Data_list):-
    maplist(pp_data,Data_list).


print_x_zeros(0).
print_x_zeros(N):-
    format('.byte 0x00~n',[]),
    N1 is N-1,
    print_x_zeros(N1).

print_header:-
    option('-asm'),!,
    format('
.intel_syntax noprefix
.globl	main
.type	main, @function
.text ~n',[]),
    % introduce some displacement to fail as soon as we make any mistake (for developing)
    % but without messing up the alignment
     format('
nop
nop
nop
nop
nop
nop
nop
nop
',[]).
    
print_header.



get_chunks(Chunks_with_padding):-
    findall(Chunk,
	    (
	     chunk_start(Chunk),Chunk\=0,
	     \+discarded_chunk(Chunk)
	    ),Chunk_addresses),
    (option('-asm')->
	 Single_instructions=[]
     ;
    findall(Instruction,
	    (instruction(EA,Size,Name,Opc1,Opc2,Opc3),
	    \+likely_ea(EA,_),
	    remaining_ea(EA),
	    get_op(Opc1,Op1),
	    get_op(Opc2,Op2),
	    get_op(Opc3,Op3),
	    Instruction=instruction(EA,Size,Name,Op1,Op2,Op3)
	    ),Single_instructions)
    ),
     empty_assoc(Empty),
     foldl(get_chunk_content,Chunk_addresses,Empty,Map),
     foldl(accum_instruction,Single_instructions,Map,Map2),
     assoc_to_values(Map2,Chunks),
     adjust_padding(Chunks,Chunks_with_padding).

get_chunk_content(Chunk_addr,Assoc,Assoc1):-
    findall(Instruction,
	    (likely_ea(EA,Chunk_addr),
	     instruction(EA,Size,Name,Opc1,Opc2,Opc3),	     
	     get_op(Opc1,Op1),
	     get_op(Opc2,Op2),
	     get_op(Opc3,Op3),
	     Instruction=instruction(EA,Size,Name,Op1,Op2,Op3)
	    ),Instructions),
    (Instructions=[]->
	 End=Chunk_addr
     ;
     last(Instructions,instruction(EA_last,Size_last,_,_,_,_)),
     End is EA_last+Size_last
    ),
    put_assoc(Chunk_addr,Assoc,chunk(Chunk_addr,End,Instructions),Assoc1).



accum_instruction(instruction(EA,Size,OpCode,Op1,Op2,Op3),Assoc,Assoc1):-
    put_assoc(EA,Assoc,instruction(EA,Size,OpCode,Op1,Op2,Op3),Assoc1).


get_op(0,none):-!.
get_op(N,reg(Name)):-
    op_regdirect(N,Name),!.
get_op(N,immediate(Immediate)):-
    op_immediate(N,Immediate),!.
get_op(N,indirect(Reg1,Reg2,Reg3,A,B,C,Size)):-
    op_indirect(N,Reg1,Reg2,Reg3,A,B,C,Size),!.


get_beg_end(chunk(Beg,End,_),Beg,End).
get_beg_end(instruction(Beg,Size,_,_,_,_),Beg,End):-
    End is Beg+Size.

adjust_padding([Last],[Last]).
adjust_padding([Chunk1,Chunk2|Chunks], Final_chunks):-
    get_beg_end(Chunk1,_Beg,End),
    get_beg_end(Chunk2,Beg2,_End2),
    (Beg2=End->
	 adjust_padding([Chunk2|Chunks],Chunks_adjusted),
	 Final_chunks=[Chunk1|Chunks_adjusted]
     ;
     Beg2>End->
	 Nop=instruction(End,1,'NOP',none,none,none),
	 adjust_padding([Nop,Chunk2|Chunks],Chunks_adjusted),
	 Final_chunks=[Chunk1|Chunks_adjusted]
     ;
     Beg2<End->
	 adjust_padding([Chunk1|Chunks],Chunks_adjusted),
	 Final_chunks=Chunks_adjusted
    ).


get_data(Data_groups):-
    findall(data_byte(EA,Content),
	    data_byte(EA,Content)
	    ,Data),
    group_data(Data,Data_groups).

group_data([],[]).

group_data([data_byte(EA,_)|Rest],[data_group(EA,plt_ref,Function)|Groups]):-
    symbolic_data(EA,_Group_content),
    plt_reference(EA,Function),!,
    split_at(7,Rest,_,Rest2),
    group_data(Rest2,Groups).

group_data([data_byte(EA,_)|Rest],[data_group(EA,labeled_pointer,Group_content)|Groups]):-
    symbolic_data(EA,Group_content),
    labeled_data(EA),!,
    split_at(7,Rest,_,Rest2),
    group_data(Rest2,Groups).

group_data([data_byte(EA,_)|Rest],[data_group(EA,pointer,Group_content)|Groups]):-
    symbolic_data(EA,Group_content),!,
    split_at(7,Rest,_,Rest2),
    group_data(Rest2,Groups).

group_data([data_byte(EA,Content)|Rest],[data_group(EA,float,Group_content)|Groups]):-
    float_data(EA),!,
    split_at(4,[data_byte(EA,Content)|Rest],Group_content,Rest2),
    group_data(Rest2,Groups).

group_data([data_byte(EA,Content)|Rest],[data_group(EA,string,String)|Groups]):-
    string(EA,End),!,
    Size is End-EA,
    split_at(Size,[data_byte(EA,Content)|Rest],Data_bytes,Rest2),
    append(String_bytes,[_],Data_bytes),
    maplist(get_data_byte_content,String_bytes,Bytes),
    clean_special_characters(Bytes,Bytes_clean),
    string_codes(String,Bytes_clean),
    group_data(Rest2,Groups).

group_data([data_byte(EA,Content)|Rest],[data_group(EA,unknown,[data_byte(EA,Content)])|Groups]):-
    labeled_data(EA),!,
    group_data(Rest,Groups).

group_data([data_byte(EA,Content)|Rest],[data_byte(EA,Content)|Groups]):-
    group_data(Rest,Groups).

clean_special_characters([],[]).
%double quote
clean_special_characters([34|Codes],[92,34|Clean_codes]):-
    !,
    clean_special_characters(Codes,Clean_codes).
% the single quote
clean_special_characters([39|Codes],[92,39|Clean_codes]):-
    !,
    clean_special_characters(Codes,Clean_codes).
%newline
clean_special_characters([10|Codes],[92,110|Clean_codes]):-
    !,
    clean_special_characters(Codes,Clean_codes).
%scape character
clean_special_characters([92|Codes],[92,92|Clean_codes]):-
    !,
    clean_special_characters(Codes,Clean_codes).

clean_special_characters([Code|Codes],[Code|Clean_codes]):-
    clean_special_characters(Codes,Clean_codes).

split_at(N,List,FirstN,Rest):-
    length(FirstN,N),
    append(FirstN,Rest,List).

get_data_byte_content(data_byte(_,Content),Content).


get_bss_data(Data_elements):-
    section('.bss',SizeSect,Base),
    End is Base+SizeSect,
      setof(EA,
	    EA^(
		bss_data(EA)
	     ;
	     %the last border
	     EA=End
	    )
	    ,Addresses),
      group_bss_data(Addresses,Data_elements).

get_bss_data([]):-
    \+section('.bss',_,_).

group_bss_data([],[]).
group_bss_data([Last],[variable(Last,0)]).
group_bss_data([Start,Next|Rest],[variable(Start,Size)|Rest_vars]):-
		   Size is Next-Start,
		   group_bss_data([Next|Rest],Rest_vars).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

skip_data_ea(EA):-
    option('-asm'),
    (
	asm_skip_section(Section),
	is_in_section(EA,Section)
     ;
     asm_skip_symbol(Symbol),
     is_in_symbol(EA,Symbol)
    ).

skip_ea(EA):-
    option('-asm'),
    ( asm_skip_section(Section),
      is_in_section(EA,Section)
     ;
     asm_skip_function(Function),
     is_in_function(EA,Function)
    ).

is_in_symbol(EA,Name):-
    symbol(Base,Size,_,_,Name),
    EA>=Base,
    End is Base+Size,
    EA<End.

is_in_section(EA,Name):-
    section(Name,Size,Base),
    EA>=Base,
    End is Base+Size,
    EA<End.
is_in_function(EA,Name):-
    function_symbol(EA_fun,Name),
    % there is no function in between
    EA>=EA_fun,
    \+ (
	function_symbol(EA_fun2,_),
	EA_fun2=<EA,
	EA_fun2>EA_fun
       ).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

cond_print_comments(EA):-
       (option('-debug')->
   	 get_comments(EA,Comments),
   	 print_comments(Comments)
     ;
     true
     ),nl.
    
pp_data(data_group(EA,_,_)):-
    skip_data_ea(EA),!.
pp_data(data_byte(EA,_)):-
    skip_data_ea(EA),!.

pp_data(data_group(EA,plt_ref,Function)):-
    print_section_header(EA),
    print_label(EA),
    print_ea(EA),
    format('.quad ~s',[Function]),
    cond_print_comments(EA),
    print_end_label(EA,8).

pp_data(data_group(EA,pointer,Content)):-
    print_section_header(EA),
    print_ea(EA),
    format('.quad .L_~16R',[Content]),
    cond_print_comments(EA),
     print_end_label(EA,8).
     
pp_data(data_group(EA,labeled_pointer,Content)):-
    print_section_header(EA),
    print_label(EA),
    print_ea(EA),
    format('.quad .L_~16R',[Content]),
    cond_print_comments(EA),
    print_end_label(EA,8).
   
pp_data(data_group(EA,float,Content)):-
    print_section_header(EA),
    print_label(EA),
    format('# float~n',[]),
    maplist(pp_data,Content).

pp_data(data_group(EA,string,Content)):-
    print_section_header(EA),
    print_label(EA),
    print_ea(EA),
    set_prolog_flag(character_escapes, false),
    format('.string "~p"',[Content]),
    set_prolog_flag(character_escapes, true),
    cond_print_comments(EA),

    get_string_length(Content,Length),
    print_end_label(EA,Length).

pp_data(data_group(EA,unknown,Content)):-
    print_section_header(EA),
    print_label(EA),
    maplist(pp_data,Content).

pp_data(data_byte(EA,Content)):-
    print_section_header(EA),
    print_ea(EA),
    format('.byte 0x~16R',[Content]),
    cond_print_comments(EA),
    print_end_label(EA,1).

print_end_label(EA,Length):-
    EA_end is EA+Length,
    labeled_data(EA_end),
    \+data_byte(EA_end,_),
    \+bss_data(EA_end),
    format('.L_~16R:~n',[EA_end]).

print_end_label(_,_).

			   
get_string_length(Content,Length1):-
    atom_codes(Content,Codes),
    length(Codes,Length),
    Length1 is Length+1.% the null character
print_ea(_):-
    option('-asm'),!,
    format('          ',[]).

print_ea(EA):-
    format('         ~16R: ',[EA]).

print_label(EA):-
    (get_global_symbol_name(EA,Name)->
	 format('~p:~n',[Name])
     ;
     true
    ),
    format('.L_~16R:~n',[EA]).





%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% pp_bss_data(variable(Start,Size)):-
%%     get_global_symbol_name(Start,Name),!,
%%     format('~p:~n',[Name]),
%%     format('.comm .L_~16R, ~p ~n',[Start,Size]).


pp_bss_data(variable(Start,0)):-!,
    format('.L_~16R:  ~n',[Start]).

pp_bss_data(variable(Start,Size)):-
    format('.L_~16R: .zero  ~p ~n',[Start,Size]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

pp_chunk(chunk(EA_chunk,_,_List)):-
    skip_ea(EA_chunk),!.
pp_chunk(instruction(EA_chunk,_,_,_,_,_)):-
    skip_ea(EA_chunk),!.


pp_chunk(chunk(EA_chunk,_,List)):-
    !,
    print_section_header(EA_chunk),
    print_function_header(EA_chunk),
    print_label(EA_chunk),   
    (option('-debug')->
	 get_comments(EA_chunk,Comments),
	 print_comments(Comments),nl
     ;
     true),
    maplist(pp_instruction,List),nl.

pp_chunk(instruction(EA,Size,Operation,Op1,Op2,Op3)):-
    print_section_header(EA),
    pp_instruction(instruction(EA,Size,Operation,Op1,Op2,Op3)).
    

print_section_header(EA):-
    section('.text',_,EA),!,
    format('~n~n#=================================== ~n',[]),
    format('.text~n',[]),
    format('#=================================== ~n~n',[]).

print_section_header(EA):-
    section(Section_name,_,EA),!,
    format('~n~n#=================================== ~n',[]),
    format('.section ~p~n',[Section_name]),
    format('#=================================== ~n~n',[]).
print_section_header(_).



print_function_header(EA):-
    is_function(EA,Name),
    format('#----------------------------------- ~n',[]),
    (0=:= EA mod 8 -> 
	 format('.align 8~n',[])
     ;
     true),
    format('.globl ~p~n',[Name]),
    format('.type ~p, @function~n',[Name]),
    format('~p:~n',[Name]),
    format('#----------------------------------- ~n',[]).

print_function_header(_).


function_complete_name(EA,'main'):-
    main_function(EA),!.
function_complete_name(EA,Name_complete):-
  function_symbol(EA,Name),
  (ambiguous_symbol(Name)->
	format(string(Name_complete),'~p_~16R',[Name,EA])
    ;
    Name_complete=Name
  ).

is_function(EA,Name_complete):-
    function_complete_name(EA,Name_complete).

%is_function(EA,Funtion_name):-
%    direct_call(_,EA),
%    atom_concat('unknown_function_',EA,Funtion_name).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% these opcodes do not really exist
adapt_opcode(fmul_to,fmul).
adapt_opcode(fsubr_to,fsub).
adapt_opcode(movsd2,movsd).
adapt_opcode(imul2,imul).
adapt_opcode(imul3,imul).
adapt_opcode(imul1,imul).
adapt_opcode(cmpsd3,cmpsd).
adapt_opcode(Operation,Operation).

opcode_suffix(Opcode,Suffix):-
    atom_codes(Opcode,Codes),
    atom_codes(' ',[Space]),
    append(_Prefix,[Space|Suffix_codes],Codes),!,
    atom_codes(Suffix,Suffix_codes).
opcode_suffix(Opcode,Opcode).


pp_instruction(instruction(EA,Size,'NOP',none,none,none)):-
    repeat_n_times((print_ea(EA),format(' nop ~n',[])),Size),
    cond_print_comments(EA).

pp_instruction(instruction(EA,_Size,String_op,Op1,none,none)):-
    opcode_suffix(String_op,Op_suffix),
    member(Op_suffix,['MOVS','CMPS']),!,
    print_ea(EA),
    downcase_atom(String_op,OpCode_l),
    get_op_indirect_size_suffix(Op1,Suffix),
    format(' ~p~p',[OpCode_l,Suffix]),
    cond_print_comments(EA).
  
pp_instruction(instruction(EA,_Size,OpCode,Op1,Op2,Op3)):-
    print_ea(EA),
    downcase_atom(OpCode,OpCode_l),
    adapt_opcode(OpCode_l,OpCode_adapted),
    format(' ~p',[OpCode_adapted]),
    %operands
    pp_operand_list([Op1,Op2,Op3],EA,1,Pretty_ops),
    % print the operands in the order: dest, src1 src2
    (append(Source_operands,[Dest_operand],Pretty_ops),
     print_with_sep([Dest_operand|Source_operands],',')
     ;
     %unless there are no operands
     Pretty_ops=[]
    ),
    cond_print_comments(EA).



is_none(none).

repeat_n_times(_Pred,0).
repeat_n_times(Pred,N):-
    N>0,
    call(Pred),
    N1 is N-1,
    repeat_n_times(Pred,N1).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pp_operand_list([],_EA,_N,[]).
pp_operand_list([none|Ops],EA,N,Pretty_ops):-
    pp_operand_list(Ops,EA,N,Pretty_ops).
pp_operand_list([Op|Ops],EA,N,[Op_pretty|Pretty_ops]):-
    pp_operand(Op,EA,N,Op_pretty),
    N1 is N+1,
    pp_operand_list(Ops,EA,N1,Pretty_ops).

pp_operand(reg(Name),_,_,Name2):-
    adapt_register(Name,Name2).

pp_operand(immediate(_Num),EA,1,Name_complete):-
    plt_reference(EA,Name),!,
    format(string(Name_complete),'OFFSET ~p',[Name]).



pp_operand(immediate(_Num),EA,_N,Name_complete):-
    direct_call(EA,Dest),
    function_complete_name(Dest,Name_complete).
 

% special case for mov from symbolic
pp_operand(immediate(Num),EA,1,Num_hex):-
    symbolic_operand(EA,1),!,
    %  instruction(EA,_,'MOV',_,_,_),!,
    (get_global_symbol_name(Num,Name_symbol)->
	 format(string(Num_hex),'OFFSET [~p]',[Name_symbol])
     ;
         format(string(Num_hex),'OFFSET .L_~16R',[Num])
    ).

pp_operand(immediate(Num),EA,N,Num_hex):-
    symbolic_operand(EA,N),!,
    format(string(Num_hex),'.L_~16R',[Num]).



pp_operand(immediate(Num),_,_,Num).
    

pp_operand(indirect('NullSReg','NullReg64','NullReg64',1,0,_,Size),EA,_,PP):-
      get_size_name(EA,Size,Name),
      format(atom(PP),'~p [~p]',[Name,0]).

pp_operand(indirect('NullSReg',Reg,'NullReg64',1,0,_,Size),EA,_,PP):-
      adapt_register(Reg,Reg_adapted),
      get_size_name(EA,Size,Name),
      format(atom(PP),'~p [~p]',[Name,Reg_adapted]).

% special case for rip relative addressing
pp_operand(indirect('NullSReg','RIP','NullReg64',1,Offset,_,Size),EA,N,PP):-
    symbolic_operand(EA,N),!,
    get_size_name(EA,Size,Name),
    instruction(EA,Size_instr,_,_,_,_),
    Address is EA+Offset+Size_instr,
    (get_global_symbol_name(Address,Name_symbol)->
	 format(atom(PP),'~p ~p[rip]',[Name,Name_symbol])
     ;
	 format(atom(PP),'~p .L_~16R[rip]',[Name,Address])
    ).

pp_operand(indirect('NullSReg','NullReg64','NullReg64',1,Offset,_,Size),EA,N,PP):-
    get_size_name(EA,Size,Name),
    %
    (get_global_symbol_name(Offset,Name_symbol)->
	 format(atom(PP),'~p [~p]',[Name,Name_symbol])
     ;
     get_offset_and_sign(Offset,EA,N,Offset1,PosNeg),
     Term=..[PosNeg,Offset1],
     format(atom(PP),'~p ~p',[Name,[Term]])
    ).
  

pp_operand(indirect('NullSReg',Reg,'NullReg64',1,Offset,_,Size),EA,N,PP):-
    adapt_register(Reg,Reg_adapted),
    get_offset_and_sign(Offset,EA,N,Offset1,PosNeg),
    get_size_name(EA,Size,Name),
    Term=..[PosNeg,Reg_adapted,Offset1],
    format(atom(PP),'~p ~p',[Name,[Term]]).

pp_operand(indirect('NullSReg','NullReg64',Reg_index,Mult,Offset,_,Size),EA,N,PP):-
    adapt_register(Reg_index,Reg_index_adapted),
    get_offset_and_sign(Offset,EA,N,Offset1,PosNeg),
    get_size_name(EA,Size,Name),
    Term=..[PosNeg,Reg_index_adapted*Mult,Offset1],
    format(atom(PP),'~p ~p',[Name,[Term]]).


pp_operand(indirect('NullSReg',Reg,Reg_index,Mult,0,_,Size),EA,_N,PP):-
    adapt_register(Reg,Reg_adapted),
    adapt_register(Reg_index,Reg_index_adapted),
    get_size_name(EA,Size,Name),
    format(atom(PP),'~p ~p',[Name,[Reg_adapted+Reg_index_adapted*Mult]]).


pp_operand(indirect('NullSReg',Reg,Reg_index,Mult,Offset,_,Size),EA,N,PP):-
    adapt_register(Reg,Reg_adapted),
    adapt_register(Reg_index,Reg_index_adapted),
    get_size_name(EA,Size,Name),
    get_offset_and_sign(Offset,EA,N,Offset1,PosNeg),
    Term=..[PosNeg,Reg_adapted+Reg_index_adapted*Mult,Offset1],
    format(atom(PP),'~p ~p',[Name,[Term]]).


pp_operand(indirect(SReg,'NullReg64','NullReg64',1,Offset,_,Size),EA,N,PP):-
    get_size_name(EA,Size,Name),
    get_offset_and_sign(Offset,EA,N,Offset1,PosNeg),
    Term=..[PosNeg,Offset1],
    format(atom(PP),'~p ~p',[Name,[SReg:Term]]).



get_offset_and_sign(Offset,EA,N,Offset1,'+'):-
    symbolic_operand(EA,N),
    moved_label(EA,N,Offset,Offset2),!,
    Diff is Offset-Offset2,
    (Diff>0->format(atom(Offset1),'.L_~16R+~p',[Offset2,Diff])
     ;
     format(atom(Offset1),'.L_~16R~p',[Offset2,Diff])
    ).

get_offset_and_sign(Offset,EA,N,Offset1,'+'):-
    symbolic_operand(EA,N),!,
    format(atom(Offset1),'.L_~16R',[Offset]).
get_offset_and_sign(Offset,_EA,_N,Offset1,'-'):-
    Offset<0,!,
    Offset1 is 0-Offset.
get_offset_and_sign(Offset,_EA,_N,Offset,'+').




%exceptions
get_size_name(EA,_Size,Name):-
    instruction(EA,_,Operation,_,_,_),
    instruction_omit_size(Operation),!,
    Name=''.
%the usual case
get_size_name(_EA,Size,Name):-
    get_size_name(Size,Name).


instruction_omit_size('PINSRW').

get_size_name(128,'').
get_size_name(0,'').
get_size_name(80,'QWORD PTR').
get_size_name(64,'QWORD PTR').
get_size_name(32,'DWORD PTR').
get_size_name(16,'WORD PTR').
get_size_name(8,'BYTE PTR').
get_size_name(Other,size(Other)).

get_op_indirect_size_suffix(indirect(_,_,_,_,_,_,Size),Suffix):-
    get_size_suffix(Size,Suffix).

get_size_suffix(128,'').
get_size_suffix(0,'').
get_size_suffix(64,'q').
get_size_suffix(32,'d').
get_size_suffix(16,'w').
get_size_suffix(8,'b').


adapt_register('R8L','R8B'):-!.
adapt_register('R9L','R9B'):-!.
adapt_register('R10L','R10B'):-!.
adapt_register('R11L','R11B'):-!.
adapt_register('R12L','R12B'):-!.
adapt_register('R13L','R13B'):-!.
adapt_register('R14L','R14B'):-!.
adapt_register('R15L','R15B'):-!.

adapt_register('ST0','ST(0)'):-!.
adapt_register('ST1','ST(1)'):-!.
adapt_register('ST2','ST(2)'):-!.
adapt_register('ST3','ST(3)'):-!.
adapt_register('ST4','ST(4)'):-!.
adapt_register('ST5','ST(5)'):-!.
adapt_register('ST6','ST(6)'):-!.
adapt_register('ST7','ST(7)'):-!.
adapt_register(Reg,Reg).

%%%%%%%%%%%%%%%%%%%
% comments for debugging

    

get_comments(EA_chunk,Comments):-
	setof(Comment,comment(EA_chunk,Comment),Comments),!.
get_comments(_EA_chunk,[]).
    
comment(EA,discarded):-
    discarded_chunk(EA).

comment(EA,overlap_with(Str_EA2)):-
    chunk_overlap(EA2,EA),
    format(string(Str_EA2),'~16R',[EA2]).

comment(EA,overlap_with(Str_EA2)):-
    chunk_overlap(EA,EA2),
    format(string(Str_EA2),'~16R',[EA2]).

comment(EA,is_called):-
    direct_call(_,EA).

comment(EA,jumped_from(Str_or)):-
    direct_jump(Or,EA),
    format(string(Str_or),'~16R',[Or]).

comment(EA,not_in_chunk):-
    \+likely_ea(EA,_).

comment(EA,symbolic_ops(Symbolic_ops)):-
    findall(Op_num,symbolic_operand(EA,Op_num),Symbolic_ops),
    Symbolic_ops\=[].

comment(EA,reg_jump):-
    reg_jump(EA).
comment(EA,indirect_jump):-
    indirect_jump(EA).

comment(EA,plt(Dest)):-
    plt_reference(EA,Dest).


comment(EA,pc_relative_jump(Dest_hex)):-
    pc_relative_jump(EA,Dest),
    format(atom(Dest_hex),'~16R',[Dest]).

comment(EA,used(Tuples)):-
    findall((EA_used_hex,Index),
	    (
	    def_used(EA,EA_used,Index),
	    pp_to_hex(EA_used,EA_used_hex)
	    ),
	    Tuples),
    Tuples\=[].

  %  maplist(pp_eaIndex_tuple,Tuples,PP_tuples).



comment(EA,labels(Refs_hex)):-
     findall(Ref,
	    preferred_label(EA,Ref),
	    Refs),
     Refs\=[],
     maplist(pp_to_hex,Refs,Refs_hex).

comment(EA,values(Values_pp)):-
    findall(value_reg(EA,Reg,EA2,Reg2,Multiplier,Offset,Steps),
	    value_reg(EA,Reg,EA2,Reg2,Multiplier,Offset,Steps),
	    Values),
    Values\=[],
    maplist(pp_value_reg,Values,Values_pp).

comment(EA,access(Values_pp)):-
    findall(data_access_pattern(Size,Mult,From),
	    data_access_pattern(EA,Size,Mult,From),
	    Values),
    Values\=[],
    maplist(pp_data_access_pattern,Values,Values_pp).

comment(EA,moved_label(Values_pp)):-
    findall(moved_label(Index,Val,New_val),
	    moved_label(EA,Index,Val,New_val),
	    Values),
    Values\=[],
    maplist(pp_moved_label,Values,Values_pp).
    
pp_moved_label(moved_label(Index,Val,New_val),
		 moved_label(Index,Val_hex,New_val_hex)):-
    pp_to_hex(Val,Val_hex),
    pp_to_hex(New_val,New_val_hex).

pp_data_access_pattern(data_access_pattern(Size,Mult,From),
		       data_access_pattern(Size,Mult,From_hex)):-
    pp_to_hex(From,From_hex).

pp_value_reg(value_reg(EA,Reg,EA2,Reg2,Multiplier,Offset,Steps),
	     value_reg(EA_hex,Reg,EA2_hex,Reg2,Multiplier,Offset,Steps)):-
    pp_to_hex(EA,EA_hex),
    pp_to_hex(EA2,EA2_hex).

pp_to_hex(EA,EA_hex):-
    format(atom(EA_hex),'~16R',[EA]).

pp_eaIndex_tuple((EA,Index,Size),(EA_hex,Index,Size)):-
    format(atom(EA_hex),'~16R',[EA]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
generate_hints(Dir):-
    option('-hints'),!,
    findall(Code_ea,
	    (
		likely_ea(Code_ea,Chunk),
		chunk_start(Chunk),
                \+discarded_chunk(Chunk)
	    ),Code_eas),
    directory_file_path(Dir,'hints',Path),
    open(Path,write,S),
    maplist(print_code_ea(S),Code_eas),
    findall(Data_ea,
	    (
		labeled_data(Data_ea)
	     ;
	     symbolic_data(Data_ea,_)
	    )
	    ,Data_eas),
    maplist(print_data_ea(S),Data_eas),
    close(S).

generate_hints(_).    

print_code_ea(S,EA):-
    format(S,'0x~16R C',[EA]),
    instruction(EA,_,_,Op1,Op2,Op3),
    exclude(is_zero,[Op1,Op2,Op3],Non_zero_ops),
    length(Non_zero_ops,N_ops),
    findall(Index,symbolic_operand(EA,Index),Indexes),
    transform_indexes(Indexes,N_ops,Indexes_tr),
    maplist(print_sym_index(S),Indexes_tr),
    format(S,'~n',[]).

is_zero(0).
print_data_ea(S,EA):-
    format(S,'0x~16R D~n',[EA]).

transform_indexes(Indexes,N_ops,Indexes_tr):-
    foldl(transform_index(N_ops),Indexes,[],Indexes_tr).

transform_index(N_ops,Index,Accum,[Index_tr|Accum]):-
    Index_tr is N_ops-Index.
 
print_sym_index(S,I):-
      	 format(S,'so~p@0',[I]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% auxiliary predicates

print_comments(Comments):-
    (Comments\=[]->
	 format('          # ',[]),
	 maplist(print_with_space,Comments)
     ;true
    ).

hex_to_dec(Hex,Dec):-
    hex_bytes(Hex,Bytes),
    byte_list_to_num(Bytes,0,Dec).

byte_list_to_num([],Accum,Accum).
byte_list_to_num([Byte|Bytes],Accum,Dec):-
    Accum2 is Byte+256*Accum,
    byte_list_to_num(Bytes,Accum2,Dec).


print_with_space(Op):-
    format(' ~p ',[Op]).

print_with_sep([],_).
print_with_sep([Last],_):-
    !,
    format(' ~p ',[Last]).
print_with_sep([X|Xs],Sep):-
    format(' ~p~p ',[X,Sep]),
    print_with_sep(Xs,Sep).


get_global_symbol_name(Address,Name):-
    symbol(Address,_,_,'GLOBAL',Name_symbol),
    clean_symbol_name_suffix(Name_symbol,Name).

clean_symbol_name_suffix(Name,Name_clean):-
    atom_codes(Name,Codes),
    atom_codes('@',[At]),
    append(Name_clean_codes,[At,At|_Suffix],Codes),!,
    atom_codes(Name_clean,Name_clean_codes).

%clean_symbol_name_suffix(Name,Name).