/**
 * Centralized Logger
 * Structured logging с контекстом
 */

import { ErrorContext } from './types';

export enum LogLevel {
  DEBUG = 'DEBUG',
  INFO = 'INFO',
  WARN = 'WARN',
  ERROR = 'ERROR',
}

interface LogEntry {
  level: LogLevel;
  message: string;
  timestamp: string;
  context?: Record<string, any>;
  error?: any;
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

  private formatLog(entry: LogEntry): string {
    const { level, message, timestamp, context, error } = entry;
    
    let log = `[${timestamp}] ${level}: ${message}`;
    
    if (context && Object.keys(context).length > 0) {
      log += ` | Context: ${JSON.stringify(context)}`;
    }
    
    if (error) {
      log += `\n  Error: ${error.message}`;
      if (error.stack) {
        log += `\n  Stack: ${error.stack}`;
      }
    }
    
    return log;
  }

  private log(level: LogLevel, message: string, context?: Record<string, any>, error?: any) {
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

  debug(message: string, context?: Record<string, any>) {
    this.log(LogLevel.DEBUG, message, context);
  }

  info(message: string, context?: Record<string, any>) {
    this.log(LogLevel.INFO, message, context);
  }

  warn(message: string, context?: Record<string, any>) {
    this.log(LogLevel.WARN, message, context);
  }

  error(message: string, error?: any, context?: Record<string, any>) {
    this.log(LogLevel.ERROR, message, context, error);
  }

  // Специализированные методы для частых кейсов
  videoProcessing(videoId: string, message: string, context?: Record<string, any>) {
    this.info(message, { videoId, ...context });
  }

  videoError(videoId: string, error: any, context?: Record<string, any>) {
    this.error(`Video processing failed: ${videoId}`, error, { videoId, ...context });
  }

  gpuRequest(operation: string, context?: Record<string, any>) {
    this.info(`GPU Server request: ${operation}`, context);
  }

  gpuError(operation: string, error: any, context?: Record<string, any>) {
    this.error(`GPU Server error: ${operation}`, error, context);
  }

  storageOperation(operation: string, context?: Record<string, any>) {
    this.info(`Storage operation: ${operation}`, context);
  }

  storageError(operation: string, error: any, context?: Record<string, any>) {
    this.error(`Storage error: ${operation}`, error, context);
  }
}

export const logger = new Logger();
