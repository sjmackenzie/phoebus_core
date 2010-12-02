-module(phoebus_core_vnode).
-author('Stewart Mackenzie <setori88@gmail.com>').
-behaviour(riak_core_vnode).

-export([start_vnode/1]).

-export([init/1,
         terminate/2,
         handle_command/3,
         is_empty/1,
         delete/1,
         handle_handoff_command/3,
         handoff_starting/2,
         handoff_cancelled/1,
         handoff_finished/2,
         handle_handoff_data/2,
         encode_handoff_item/2]).

-include_lib("phoebus_core_vnode.hrl").

%% API
start_vnode(I) ->
    riak_core_vnode_master:get_vnode_pid(I, phoebus_core_vnode)
.
%% VNode callbacks

init(_X) ->
  not_implemented.

handle_command(_X,_Y,_Z) ->
  not_implemented.

is_empty(_X) ->
  not_implemented.

delete(_X) ->
  not_implemented.

handle_handoff_command(_X,_Y,_Z) ->
  not_implemented.

handoff_starting(_X, _Y) ->
  not_implemented.

handoff_cancelled(_X) ->
  not_implemented.

handoff_finished(_X,_Y) ->
  not_implemented.

handle_handoff_data(_X,_Y) ->
  not_implemented.

encode_handoff_item(_X,_Y) ->
  not_implemented.

terminate(_Reason, _X) ->
  not_implemented.
