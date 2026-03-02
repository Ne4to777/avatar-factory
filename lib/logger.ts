/**
 * Centralized Logger
 * Structured logging с контекстом
 */

export enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR',
}

interface LogContext {
  [key: string]: unknown;
}

interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: string;
  context?: LogContext;
  error?: unknown;
}

class Logger {
  private minLevel: LogLevel;

  constructor() {
    const level = process.env.LOG_LEVEL || 'INFO';
    this.minLevel = LogLevel[level as keyof typeof LogLevel] || LogLevel.INFO;
  }

  private shouldLog(level: LogLevel): boolean {
    const levels = [LogLevel.DEBUG, LogLevel.INFO, LogLevel.WARN, LogLevel.ERROR];
    return levels.indexOf(level) >= levels.indexOf(this.minLevel);
  }

  private formatError(error: unknown): string {
    if (error instanceof Error) {
      return error.message;
    }
    if (error && typeof error === 'object' && 'message' in error) {
      const msg = (error as { message: unknown }).message;
      if (typeof msg === 'string') return msg;
    }
    return String(error);
  }

  private formatLog(entry: LogEntry): string {
    const { level, message, timestamp, context, error } = entry;
    
    let log = `[${timestamp}] ${level}: ${message}`;
    
    if (context && Object.keys(context).length > 0) {
      log += ` | Context: ${JSON.stringify(context)}`;
    }
    
    if (error) {
      log += `\n  Error: ${this.formatError(error)}`;
      if (error instanceof Error && error.stack) {
        log += `\n  Stack: ${error.stack}`;
      }
    }
    
    return log;
  }

  private log(level: LogLevel, message: string, context?: LogContext, error?: unknown) {
    if (!this.shouldLog(level)) return;

    const entry: LogEntry = {
      level,
      message,
      timestamp: new Date().toISOString(),
      context,
      error,
    };

    const formatted = this.formatLog(entry);

    switch (level) {
      case LogLevel.ERROR:
        console.error(formatted);
        break;
      case LogLevel.WARN:
        console.warn(formatted);
        break;
      case LogLevel.DEBUG:
        console.debug(formatted);
        break;
      default:
        console.log(formatted);
    }
  }

  debug(message: string, context?: LogContext) {
    this.log(LogLevel.DEBUG, message, context);
  }

  info(message: string, context?: LogContext) {
    this.log(LogLevel.INFO, message, context);
  }

  warn(message: string, context?: LogContext) {
    this.log(LogLevel.WARN, message, context);
  }

  error(message: string, error?: unknown, context?: LogContext) {
    this.log(LogLevel.ERROR, message, context, error);
  }

  // Специализированные методы для частых кейсов
  videoProcessing(videoId: string, message: string, context?: LogContext) {
    this.info(message, { videoId, ...context });
  }

  videoError(videoId: string, error: unknown, context?: LogContext) {
    this.error(`Video processing failed: ${videoId}`, error, { videoId, ...context });
  }

  gpuRequest(operation: string, context?: LogContext) {
    this.info(`GPU Server request: ${operation}`, context);
  }

  gpuError(operation: string, error: unknown, context?: LogContext) {
    this.error(`GPU Server error: ${operation}`, error, context);
  }

  storageOperation(operation: string, context?: LogContext) {
    this.info(`Storage operation: ${operation}`, context);
  }

  storageError(operation: string, error: unknown, context?: LogContext) {
    this.error(`Storage error: ${operation}`, error, context);
  }
}

export const logger = new Logger();
