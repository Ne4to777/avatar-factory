# Testing Documentation - Avatar Factory

## 📋 Overview

Проект использует **Vitest** для unit, integration и E2E тестов.

## 🎯 Test Coverage Goals

- **Unit Tests**: 70%+ coverage
- **Integration Tests**: 20%+ coverage  
- **E2E Tests**: 10%+ coverage
- **Total**: 90%+ production-ready coverage

## 🧪 Current Test Status

### Unit Tests ✅ 135 tests passing 🎉

```
✓ tests/unit/gpu-client.simple.test.ts (13 tests)
✓ tests/unit/types.test.ts (14 tests)
✓ tests/unit/queue.test.ts (22 tests)
✓ tests/unit/storage.test.ts (25 tests)
✓ tests/unit/config.test.ts (16 tests)
✓ tests/unit/video.test.ts (30 tests)
✓ tests/unit/logger.test.ts (15 tests)
```

#### Modules Tested:

1. **`lib/types.ts`** (14 tests)
   - ✅ Custom error classes (AvatarFactoryError, GPUServerError, etc.)
   - ✅ Error inheritance и type identification
   - ✅ Context в errors
   - ✅ Error serialization

2. **`lib/config.ts`** (16 tests)
   - ✅ Video dimensions для всех форматов
   - ✅ Default конфигурация
   - ✅ Voice и queue configuration
   - ✅ Validation helpers (validateVideoFormat, validateTextLength, validateUrl)

3. **`lib/logger.ts`** (15 tests)
   - ✅ Log levels (DEBUG, INFO, WARN, ERROR)
   - ✅ Context logging
   - ✅ Error logging с stack trace
   - ✅ Specialized methods (videoProcessing, gpuRequest, storageOperation)
   - ✅ Timestamp formatting

4. **GPU Client Validation** (13 tests)
   - ✅ Text validation (empty, whitespace, length)
   - ✅ Prompt validation
   - ✅ Buffer validation
   - ✅ File path validation
   - ✅ Error handling

5. **`lib/storage.ts` Logic** (25 tests)
   - ✅ File path validation
   - ✅ Key generation
   - ✅ Content type detection
   - ✅ URL parsing
   - ✅ Buffer validation
   - ✅ Folder types
   - ✅ Error handling
   - ✅ File size handling
   - ✅ S3 configuration

6. **`lib/queue.ts` Logic** (22 tests)
   - ✅ Queue configuration
   - ✅ VideoJobData structure
   - ✅ VideoJobResult structure
   - ✅ Job priority calculation
   - ✅ Job state management
   - ✅ Retry logic
   - ✅ Queue metrics
   - ✅ Job cleanup

7. **`lib/video.ts` Logic** (30 tests)
   - ✅ Video dimensions
   - ✅ Video configuration
   - ✅ FPS parsing
   - ✅ Video metadata
   - ✅ File path validation
   - ✅ Format validation
   - ✅ FFmpeg command building
   - ✅ Thumbnail generation
   - ✅ Error handling
   - ✅ Duration validation
   - ✅ Filter graph

### Coverage Report ✅

```
File           | % Stmts | % Branch | % Funcs | % Lines |
---------------|---------|----------|---------|---------|
lib/types.ts   |   100%  |   100%   |   100%  |   100%  | ✅
lib/logger.ts  |  97.6%  |    85%   |   100%  |   100%  | ✅
lib/config.ts  |  91.6%  |    75%   |   100%  |  91.3%  | ✅
```

**Note**: Integration tests требуются для полного покрытия `gpu-client.ts`, `storage.ts`, `queue.ts`, `video.ts`, `workers/` и API routes.

## 🛠️ Testing Infrastructure

### Setup

```bash
npm install -D vitest @vitest/ui @vitest/coverage-v8 happy-dom
```

### Configuration

- **Config**: `vitest.config.ts`
- **Setup**: `tests/setup.ts`
- **Mocks**: `tests/mocks/`
- **Tests**: 
  - `tests/unit/` - Unit tests
  - `tests/integration/` - Integration tests
  - `tests/e2e/` - End-to-end tests

### Test Scripts

```json
{
  "test": "vitest run",
  "test:unit": "vitest run tests/unit",
  "test:watch": "vitest watch",
  "test:coverage": "vitest run --coverage",
  "test:ui": "vitest --ui",
  "test:e2e": "tsx test-video-generation.ts"
}
```

## 🚀 Running Tests

### Run all tests
```bash
npm test
```

### Run unit tests only
```bash
npm run test:unit
```

### Watch mode (re-run on file changes)
```bash
npm run test:watch
```

### Coverage report
```bash
npm run test:coverage
```

### Interactive UI
```bash
npm run test:ui
```

### E2E test
```bash
npm run test:e2e
```

## 📁 Test File Structure

```
tests/
├── setup.ts                          # Global test setup
├── mocks/                           
│   └── gpu-server.mock.ts           # GPU server mocks
├── unit/                            # Unit tests (58 tests)
│   ├── types.test.ts                # Error classes
│   ├── config.test.ts               # Configuration & validation
│   ├── logger.test.ts               # Structured logging
│   └── gpu-client.simple.test.ts    # GPU client validation
├── integration/                     # Integration tests (TODO)
│   └── ...
└── e2e/                            # E2E tests (TODO)
    └── ...
```

## 🧩 Mock Utilities

### GPU Server Mocks

Located in `tests/mocks/gpu-server.mock.ts`:

- `mockGPUHealthCheck` - Mock health check response
- `createMockAudioBuffer(duration)` - Generate WAV buffer
- `createMockVideoBuffer(width, height)` - Generate MP4 buffer
- `createMockImageBuffer(width, height)` - Generate PNG buffer
- `mockGPUClientSuccess` - Mock successful GPU client
- `mockGPUClientError` - Mock failing GPU client

Example usage:

```typescript
import { createMockAudioBuffer, mockGPUClientSuccess } from '../mocks/gpu-server.mock';

it('should generate audio', async () => {
  const audio = createMockAudioBuffer(2); // 2 seconds
  expect(Buffer.isBuffer(audio)).toBe(true);
});
```

### Global Test Utilities

Available via `global.testUtils`:

```typescript
// Create temporary test file
const filePath = await global.testUtils.createTempFile('content', '.txt');

// Cleanup temp files
await global.testUtils.cleanupTempFiles([filePath]);
```

## 📊 Coverage Thresholds

```typescript
coverage: {
  thresholds: {
    lines: 70,
    functions: 70,
    branches: 60,
    statements: 70,
  },
}
```

## ✅ Test Patterns

### Unit Test Structure

```typescript
import { describe, it, expect, vi, beforeEach } from 'vitest';

describe('Module Name', () => {
  describe('Function Name', () => {
    it('should do expected behavior', () => {
      // Arrange
      const input = 'test';
      
      // Act
      const result = functionUnderTest(input);
      
      // Assert
      expect(result).toBe('expected');
    });
  });
});
```

### Testing Error Handling

```typescript
it('should throw ValidationError', () => {
  expect(() => validateText('')).toThrow();
  
  try {
    validateText('');
    expect.fail('Should have thrown');
  } catch (error) {
    expect(error).toBeInstanceOf(Error);
    expect((error as any).code).toBe('VALIDATION_ERROR');
  }
});
```

### Testing Async Functions

```typescript
it('should handle async operation', async () => {
  const result = await asyncFunction();
  expect(result).toBe('success');
});

it('should handle async rejection', async () => {
  await expect(failingFunction()).rejects.toThrow();
});
```

### Mocking Console

```typescript
import { vi, beforeEach, afterEach } from 'vitest';

let consoleLogSpy: any;

beforeEach(() => {
  consoleLogSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
});

afterEach(() => {
  vi.restoreAllMocks();
});

it('should log message', () => {
  logger.info('Test');
  expect(consoleLogSpy).toHaveBeenCalledOnce();
});
```

## 🎯 Next Steps for Testing

### Immediate (TODO)

1. **Integration Tests** (planned)
   - API routes testing
   - Database operations
   - Queue operations
   - Worker pipeline

2. **More Unit Tests** (planned)
   - `lib/storage.ts` - Storage operations
   - `lib/queue.ts` - Queue management
   - `lib/video.ts` - Video processing
   - `workers/video-worker.ts` - Worker logic

3. **E2E Tests** (planned)
   - Full video generation pipeline
   - Error scenarios
   - Recovery mechanisms

### Future Enhancements

- [ ] Snapshot testing для video composition
- [ ] Performance benchmarks
- [ ] Load testing для queue
- [ ] Visual regression testing (Playwright)
- [ ] Contract testing для GPU server
- [ ] Mutation testing

## 🐛 Debugging Tests

### VSCode Integration

Add to `.vscode/launch.json`:

```json
{
  "type": "node",
  "request": "launch",
  "name": "Debug Vitest Tests",
  "runtimeExecutable": "npm",
  "runtimeArgs": ["run", "test:watch"],
  "console": "integratedTerminal",
  "internalConsoleOptions": "neverOpen"
}
```

### Debug Single Test

```bash
npx vitest run tests/unit/types.test.ts
```

### Debug with --inspect

```bash
node --inspect-brk ./node_modules/.bin/vitest run
```

## 📚 Best Practices

1. **Test Isolation**: Each test should be independent
2. **Descriptive Names**: Use clear "should..." format
3. **AAA Pattern**: Arrange, Act, Assert
4. **Mock External Dependencies**: Don't hit real GPU/DB/S3
5. **Test Edge Cases**: Empty strings, null, undefined, extreme values
6. **Use TypeScript**: Full type safety in tests
7. **Keep Tests Fast**: Mock expensive operations
8. **Don't Test Implementation**: Test behavior, not internals

## 🔍 Common Issues

### Issue: "Module not found"
**Solution**: Check `vitest.config.ts` alias configuration

### Issue: "Cannot find module @/..."
**Solution**: Ensure path alias matches tsconfig.json

### Issue: "Tests timing out"
**Solution**: Increase `testTimeout` in vitest.config.ts

### Issue: "Coverage not generated"
**Solution**: Run `npm run test:coverage` instead of `npm test`

## 📈 Test Metrics

Current Status (as of 22.02.2026 - Updated):

```
Test Files:  7 passed (7)
Tests:       135 passed (135) ✅
Duration:    ~150ms
Coverage:    
  - types.ts:   100% ✅
  - logger.ts:  97.6% ✅
  - config.ts:  91.6% ✅
  - Overall:    11.7% (integration tests needed)
```

Target Status:

```
Test Files:  15+ passed
Tests:       250+ passed
Coverage:    90%+ (with integration tests)
Duration:    <5s
```

## 🎓 Resources

- [Vitest Documentation](https://vitest.dev/)
- [Testing Best Practices](https://github.com/goldbergyoni/javascript-testing-best-practices)
- [Test Driven Development](https://martinfowler.com/bliki/TestDrivenDevelopment.html)
