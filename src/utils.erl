-module(utils).
-include("eventMessage.hrl").
-export([parse_input/1,seqToInt/1,tokenize/1,typeOfMsg/1]).

% It parses the input coming from an event source 
% or a client. For any non recognized input, it returns 
% the undefined atom. 
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

% Transform an integer sequence  to 
% an erlang native integer e.g.: "2345" -> 2345.
seqToInt(Sq) ->
	case string:to_integer(Sq) of 
		{Int,_} -> Int
	end.

% Strips characters such as |\r\n from the input sequence.
tokenize(Input) ->  
	string:tokens(binary_to_list(Input),"|\r\n").
	
% Returns the type of message
typeOfMsg(M = #eventMessage{}) -> M#eventMessage.type.
