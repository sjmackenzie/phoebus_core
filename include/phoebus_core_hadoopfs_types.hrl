-ifndef(_phoebus_core_hadoopfs_types_included).
-define(_phoebus_core_hadoopfs_types_included, yeah).

-record(thriftHandle, {id}).

-record(pathname, {pathname}).

-record(fileStatus, {path, length, isdir, block_replication, blocksize, modification_time, permission, owner, group}).

-record(blockLocation, {hosts, names, offset, length}).

-record(malformedInputException, {message}).

-record(thriftIOException, {message}).

-endif.
