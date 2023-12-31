@tool
extends Node

class_name Log

signal log_message(level:LogLevel,message:String)

enum LogLevel {
	QUACK,
	DEBUG,
	INFO,
	WARN,
	ERROR,
	FATAL,
}

var CURRENT_LOG_LEVEL=LogLevel.INFO
var write_logs:bool = false
var rotate_logs: bool = true
var log_path:String = "user://logs/game.log"
var log_path_backup:String = "user://logs/game_old.log"
var _config

var _prefix=""
var _default_args={}

var _file

func _ready():
	_set_loglevel(Config.get_var("log-level","quack"))
	_rotate_logs()

func _rotate_logs():
	var dir = DirAccess.open("user://")
	if !dir.dir_exists("logs"):
		dir.make_dir("logs")
	
	if dir.file_exists(log_path):
		dir.copy(log_path, log_path_backup)
		dir.remove(log_path)
	
func _set_loglevel(level:String):
	logger("setting log level",{"level":level},LogLevel.INFO)
	match level.to_lower():
		"quack":
			CURRENT_LOG_LEVEL = LogLevel.QUACK
		"debug":
			CURRENT_LOG_LEVEL = LogLevel.DEBUG
		"info":
			CURRENT_LOG_LEVEL = LogLevel.INFO
		"warn":
			CURRENT_LOG_LEVEL = LogLevel.WARN
		"error":
			CURRENT_LOG_LEVEL = LogLevel.ERROR
		"fatal":
			CURRENT_LOG_LEVEL = LogLevel.FATAL

func with(prefix:String="",args:Dictionary={}) ->Log :
	var l = Log.new()
	l.CURRENT_LOG_LEVEL = self.CURRENT_LOG_LEVEL
	l._prefix = prefix
	for k in args:
		l._default_args[k] = args[k]
	return l

func logger(message:String,values,log_level=LogLevel.INFO):
	if CURRENT_LOG_LEVEL > log_level :
		return

	var now = Time.get_datetime_dict_from_system(true)
	var msg : Dictionary = {
		"log": {
			"level": LogLevel.keys()[log_level],
			"message": message,
			"time": "{year}-{month}-{day}T{hour}:{minute}:{second}Z".format(now)
		}
	}

	if _prefix:
		msg.prefix = _prefix
	
	match typeof(values):
		TYPE_ARRAY:
			if values.size() > 0:
				msg[values] = values
		TYPE_DICTIONARY:
			for k in _default_args:
				values[k] = _default_args[k]
			if values.size() > 0:
				msg.log = { "text": message, "level": log_level }
				for k in values:
					if typeof(values[k]) == TYPE_OBJECT && values[k] != null:
						msg[k] = JsonData.to_dict(values[k],false)
					else:
						msg[k] = values[k]
		TYPE_PACKED_BYTE_ARRAY:
			if values == null:
				pass
			else:
				msg.merge(JsonData.unmarshal_bytes_to_dict(values))
		TYPE_OBJECT:
			if values == null:
				pass
			else:
				msg.merge(JsonData.to_dict(values,false))
		TYPE_NIL:
			pass
		_:
			msg.values = values

	if OS.get_main_thread_id() != OS.get_thread_caller_id() and log_level == LogLevel.DEBUG:
		print("[%d]Cannot retrieve debug info outside the main thread:\n\t%s" % [OS.get_thread_caller_id(),msg])
		return
	_write_logs(msg)
	emit_signal("log_message", log_level, msg)
	match log_level:
		LogLevel.QUACK:
			print("QUACK\n\n")
			print(msg)
			print("\n\nQUACK")
		LogLevel.DEBUG:
			print(msg)
			print_stack()
		LogLevel.INFO:
			print(msg)
		LogLevel.WARN:
			print(msg)
			push_warning(msg)
			print_stack()
		LogLevel.ERROR:
			push_error(msg)
			printerr(msg)
			print_stack()
			print_tree()
		LogLevel.FATAL:
			push_error(msg)
			printerr(msg)
			print_stack()
			print_tree()
			get_tree().quit()
		_:
			print(msg)
func dump(values={}, log_level=LogLevel.INFO):
	call_thread_safe("logger", null, values, log_level)

func quack(message:String, values={}):
	call_thread_safe("logger",message,values,LogLevel.QUACK)

func debug(message:String,values={}):
	call_thread_safe("logger",message,values,LogLevel.DEBUG)

func info(message:String,values={}):
	call_thread_safe("logger",message,values)

func warn(message:String,values={}):
	call_thread_safe("logger",message,values,LogLevel.WARN)

func error(message:String,values={}):
	call_thread_safe("logger",message,values,LogLevel.ERROR)

func fatal(message:String,values={}):
	call_thread_safe("logger",message,values,LogLevel.FATAL)
	

func _write_logs(message:Dictionary):
	if !write_logs:
		return
	if _file == null:
		_file = FileAccess.open(log_path,FileAccess.WRITE)
	_file.store_line(JSON.stringify(message))
	pass
	
