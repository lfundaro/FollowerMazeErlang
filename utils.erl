-module(utils).
-include("eventMessage.hrl").
-compile(export_all).

parse_input(Input) ->
	case tokenize(Input) of
		[Sq,"F",Fu,Tu] ->
			#eventMessage{payload=Input,
						  seq=seqToInt(Sq),
						  type=follow,
						  fromUser=Fu,
						  toUser=Tu};
		[Sq,"B"] -> 
			#eventMessage{payload=Input,
						  seq=seqToInt(Sq),
						  type=broadcast};
		[Sq,"U",Fu,Tu] -> 
			#eventMessage{payload=Input,
						  seq=seqToInt(Sq),
						  type=unfollow,
						  fromUser=Fu,
						  toUser=Tu};
		[Sq,"P",Fu,Tu] ->
			#eventMessage{payload=Input,
						  seq=seqToInt(Sq),
						  type=private_message,
						  fromUser=Fu,
						  toUser=Tu};
		[Sq,"S",Fu] ->
			#eventMessage{payload=Input,
						  seq=seqToInt(Sq),
						  type=status_update,
						  fromUser=Fu};	
		[ClientId] -> ClientId;
		_ -> undefined
	end.
	
seqToInt(Sq) ->
	case string:to_integer(Sq) of 
		{Int,_} -> Int
	end.
	
tokenize(Input) ->  
	string:tokens(binary_to_list(Input),"|\r\n").
	
typeOfMsg(M = #eventMessage{}) -> M#eventMessage.type.
