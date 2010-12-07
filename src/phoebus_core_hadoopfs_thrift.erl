%%
%% Autogenerated by Thrift
%%
%% DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
%%

-module(phoebus_core_hadoopfs_thrift).
-behaviour(thrift_service).


-include("phoebus_core_hadoopfs_thrift.hrl").

-export([struct_info/1, function_info/2]).

struct_info('i am a dummy struct') -> undefined.
%%% interface
% setInactivityTimeoutPeriod(This, PeriodInSeconds)
function_info('setInactivityTimeoutPeriod', params_type) ->
  {struct, [{1, i64}]}
;
function_info('setInactivityTimeoutPeriod', reply_type) ->
  {struct, []};
function_info('setInactivityTimeoutPeriod', exceptions) ->
  {struct, []}
;
% shutdown(This, Status)
function_info('shutdown', params_type) ->
  {struct, [{1, i32}]}
;
function_info('shutdown', reply_type) ->
  {struct, []};
function_info('shutdown', exceptions) ->
  {struct, []}
;
% create(This, Path)
function_info('create', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}}]}
;
function_info('create', reply_type) ->
  {struct, {'phoebus_core_hadoopfs_types', 'thriftHandle'}};
function_info('create', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% createFile(This, Path, Mode, Overwrite, BufferSize, Block_replication, Blocksize)
function_info('createFile', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}},
  {2, i16},
  {3, bool},
  {4, i32},
  {5, i16},
  {6, i64}]}
;
function_info('createFile', reply_type) ->
  {struct, {'phoebus_core_hadoopfs_types', 'thriftHandle'}};
function_info('createFile', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% open(This, Path)
function_info('open', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}}]}
;
function_info('open', reply_type) ->
  {struct, {'phoebus_core_hadoopfs_types', 'thriftHandle'}};
function_info('open', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% append(This, Path)
function_info('append', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}}]}
;
function_info('append', reply_type) ->
  {struct, {'phoebus_core_hadoopfs_types', 'thriftHandle'}};
function_info('append', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% write(This, Handle, Data)
function_info('write', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftHandle'}}},
  {-1, string}]}
;
function_info('write', reply_type) ->
  bool;
function_info('write', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% read(This, Handle, Offset, Size)
function_info('read', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftHandle'}}},
  {-1, i64},
  {-2, i32}]}
;
function_info('read', reply_type) ->
  string;
function_info('read', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% close(This, Out)
function_info('close', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftHandle'}}}]}
;
function_info('close', reply_type) ->
  bool;
function_info('close', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% rm(This, Path, Recursive)
function_info('rm', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}},
  {2, bool}]}
;
function_info('rm', reply_type) ->
  bool;
function_info('rm', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% rename(This, Path, Dest)
function_info('rename', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}},
  {2, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}}]}
;
function_info('rename', reply_type) ->
  bool;
function_info('rename', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% mkdirs(This, Path)
function_info('mkdirs', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}}]}
;
function_info('mkdirs', reply_type) ->
  bool;
function_info('mkdirs', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% exists(This, Path)
function_info('exists', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}}]}
;
function_info('exists', reply_type) ->
  bool;
function_info('exists', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% stat(This, Path)
function_info('stat', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}}]}
;
function_info('stat', reply_type) ->
  {struct, {'phoebus_core_hadoopfs_types', 'fileStatus'}};
function_info('stat', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% listStatus(This, Path)
function_info('listStatus', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}}]}
;
function_info('listStatus', reply_type) ->
  {list, {struct, {'phoebus_core_hadoopfs_types', 'fileStatus'}}};
function_info('listStatus', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% chmod(This, Path, Mode)
function_info('chmod', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}},
  {2, i16}]}
;
function_info('chmod', reply_type) ->
  {struct, []};
function_info('chmod', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% chown(This, Path, Owner, Group)
function_info('chown', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}},
  {2, string},
  {3, string}]}
;
function_info('chown', reply_type) ->
  {struct, []};
function_info('chown', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% setReplication(This, Path, Replication)
function_info('setReplication', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}},
  {2, i16}]}
;
function_info('setReplication', reply_type) ->
  {struct, []};
function_info('setReplication', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
% getFileBlockLocations(This, Path, Start, Length)
function_info('getFileBlockLocations', params_type) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'pathname'}}},
  {2, i64},
  {3, i64}]}
;
function_info('getFileBlockLocations', reply_type) ->
  {list, {struct, {'phoebus_core_hadoopfs_types', 'blockLocation'}}};
function_info('getFileBlockLocations', exceptions) ->
  {struct, [{1, {struct, {'phoebus_core_hadoopfs_types', 'thriftIOException'}}}]}
;
function_info(_Func, _Info) -> no_function.
