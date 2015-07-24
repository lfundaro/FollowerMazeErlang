-module(dispatcher).
-include("eventMessage.hrl").
-export([init/0,loop/1,processMessages/2,handleMessage/2,handleFollow/2,addFollower/3,removeFollower/3,
		handleUnfollow/2,handleBroadcast/2,handlePrivateMessage/2,handleStatusUpdate/2,getWorkersPid/1,
		retrieveFollowerList/2,getFollowersPids/2]).

% This record maintains the following information:
	% - clients: a dictionary that maps from a ClientId to WorkerPid. 
			   % Each client is assigned a WorkerPid that will notify him, 
			   % of events that pertain him. 
	% - counter_worker: contains the counter_worker process PID. A counter 
					  % worker is in charge of reordering all the messages that 
				      % come from the event source. As soon as it has a complete 
					  % sequence, e.g.: [Msg1,Ms2,Ms3,Msg5] it sends back to the dis
					  % patcher the signal to process [Msg1,Ms2,Ms3].
	% - followers: a dictionary that maps from ClientId to a list of this client's
				 % followers. The follower clients are also represented by ClientId's.
-record(state, {clients,
				counter_worker,
				followers}).
				
init() ->
	process_flag(trap_exit, true),
	loop(#state{clients = dict:new(),
				counter_worker = spawn(fun() -> counter_worker:init() end),
				followers=dict:new()}).

% This is the core of the Dispatcher Process. It listens to event 
% coming from the eventSource identified by {event,M}, client subscriptions 
% identified by {subscribe,ClientId,Socket} and process_messages issued by a 
% counter worker (see counter_worker.erl), to process a message and send it 
% to the worker assigned to a client. Finally, it listens to any shutdown signal 
% so it exits nicely, having called before any of its spawned workers.
loop(S = #state{}) ->
	receive
		{subscribe,ClientId,Socket} ->
			WorkerPid = spawn(fun() -> worker:init(Socket) end),
			gen_tcp:controlling_process(Socket,WorkerPid),
			NewClients = dict:append(ClientId,WorkerPid,S#state.clients),
			loop(S#state{clients=NewClients});
		{event, M} ->
			S#state.counter_worker ! {new_event,M,self()},
			loop(S);
		{process_messages,MessagesToProcess} ->
			loop(processMessages(S, MessagesToProcess));
		{'EXIT', Pid, shutdown} ->
			lists:foreach(fun(A) -> A ! {'EXIT', Pid, shutdown} end,getWorkersPid(S)),
			S#state.counter_worker ! {'EXIT', Pid, shutdown},
			exit(normal);
		_ -> loop(S)
	end.
	
% For every message that is ready to be sent in the ordered (by sequence) list 
% of MessagesToProcess it adds or removes followers (if message is of type follow/unfollow) 
% to the followers list and it finally forwards the message to the appropiate worker 
% that is in charge of a certain connected client.
processMessages(S = #state{}, MessagesToProcess) ->
	NewState = lists:foldl(fun ?MODULE:handleMessage/2,S,MessagesToProcess),
	NewState.

% This function does all the message processing. It takes a message, 
% and a State, and depending of the type of message, it takes a certain 
% action.
handleMessage(M = #eventMessage{}, S = #state{}) ->
	case utils:typeOfMsg(M) of
		follow ->
			handleFollow(M,S);
		unfollow ->
			handleUnfollow(M,S);
		broadcast ->
			handleBroadcast(M,S);
		private_message ->
			handlePrivateMessage(M,S);
		status_update ->
			handleStatusUpdate(M,S);
		_ -> S
	end.

% Adds a follower to a ClientId in the follower dictionary belonging to 
% this process State. Finally, it notifies the worker who is in charge of 
% the ToUserId as long as it is a connected client, otherwise, it drops the 
% message.
handleFollow(M = #eventMessage{},S = #state{}) -> 
	SS = addFollower(M#eventMessage.fromUser,M#eventMessage.toUser,S),
	case dict:find(M#eventMessage.toUser,SS#state.clients) of
		{ok,[ToUserWorkerPid]} -> 
					ToUserWorkerPid ! {notify,M},
					SS;
		_ -> SS
	end.

% Adds a follower to the followers structure. If the user who is being followed, 
% does not exists, it is automatically inserted as a new key of this dictionary.	
addFollower(NewFollower,To, S = #state{}) -> 
	S#state{followers=dict:update(To,fun(V) -> [NewFollower|V] end,[NewFollower], S#state.followers)}.

% Removes a follower from the followers structure.
removeFollower(NewUnFollower,To, S = #state{}) -> 
	S#state{followers=dict:update(To,fun(V) -> lists:delete(NewUnFollower,V) end,[],S#state.followers)}.

% Does not make a notification, but makes changes on the followers structure.	
handleUnfollow(M = #eventMessage{},S = #state{}) -> 
	removeFollower(M#eventMessage.fromUser,M#eventMessage.toUser,S).

% For each connected client, it sends the Broadcast message to any 
% of its assigned workers.	
handleBroadcast(M,S = #state{}) ->
	lists:foreach(fun(A) -> A ! {notify,M} end,getWorkersPid(S)),
	S.
	
% Returns a list of all workers PID's that are assigned to a connected client.
getWorkersPid(S = #state{}) ->
	dict:fold(fun(_,[WorkerPid],Acc) -> [WorkerPid|Acc] end,[],S#state.clients).
	
% Checks if the toUserId exists as a connected client and if so, it sends 
% the notification.
handlePrivateMessage(M = #eventMessage{},S = #state{}) -> 
	case dict:find(M#eventMessage.toUser,S#state.clients) of
		{ok,[WorkerPid]} -> 
			WorkerPid ! {notify,M},
			S;
		error -> S
	end.

% It starts by getting the list of followers from the FromUserId, 
% for each one it gets their worker's Pids, and sends the notification 
% for each worker Pid that was retrieved as a result of this operation.
handleStatusUpdate(M = #eventMessage{},S = #state{}) ->
	ListOfFollowers = retrieveFollowerList(M#eventMessage.fromUser,S),
	FollowersPids = lists:foldl(fun(E, Acc) -> 
											case dict:find(E, S#state.clients) of
												{ok,[WorkerPid]} -> [WorkerPid|Acc];
												error -> Acc
											end
											end, [], ListOfFollowers),
	lists:foreach(fun(W) -> W ! {notify,M} end, FollowersPids),
	S.
	
% Retrieves the follower list of User.
retrieveFollowerList(User,S = #state{}) -> 
	case dict:find(User,S#state.followers) of 
		{ok,L} -> L;
		error -> []
	end.
	
% Maps a list of ClientId's to their corresponding WorkerPid's.
% This function is particularly useful for the handleStatusUpdate function.
getFollowersPids([],_) -> [];
getFollowersPids(Followers,S = #state{}) ->
	lists:foldl(fun(E,Acc) ->  
							case dict:find(E,S#state.clients) of 
								{ok,[WorkerPid]} -> [WorkerPid|Acc];
								_ -> Acc
							end
							end,[],Followers).	