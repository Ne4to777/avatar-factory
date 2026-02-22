# Tests - Avatar Factory

Comprehensive test suite для Avatar Factory проекта.

## 📊 Quick Stats

```
✅ 135 tests passing
⚡ ~150ms execution time
📁 7 test suites
🎯 91-100% coverage (core modules)
```

## 📁 Structure

```
tests/
├── setup.ts                           # Global test configuration
├── mocks/                            # Reusable mock utilities
│   └── gpu-server.mock.ts           # GPU server mocks
├── unit/                             # Unit tests (135 tests)
│   ├── types.test.ts                # Error classes (14 tests)
│   ├── logger.test.ts               # Structured logging (15 tests)
│   ├── config.test.ts               # Configuration (16 tests)
│   ├── gpu-client.simple.test.ts    # GPU validation (13 tests)
│   ├── storage.test.ts              # Storage logic (25 tests)
│   ├── queue.test.ts                # Queue logic (22 tests)
│   └── video.test.ts                # Video logic (30 tests)
├── integration/                      # Integration tests (TODO)
└── e2e/                             # End-to-end tests (TODO)
```

## 🚀 Running Tests

### Quick Start
```bash
# Run all unit tests
npm run test:unit

# Watch mode (auto re-run on changes)
npm run test:watch

# With coverage report
npm run test:coverage

# Interactive UI
npm run test:ui
```

### Specific Test Suites
```bash
# Run single test file
npx vitest run tests/unit/types.test.ts

# Run tests matching pattern
npx vitest run tests/unit/*storage*
```

## 📋 Test Suites

### Unit Tests

#### 1. **types.test.ts** (14 tests)
Tests custom error classes:
- AvatarFactoryError
- GPUServerError
- StorageError
- ValidationError
- VideoProcessingError

**Coverage**: 100% ✅

#### 2. **logger.test.ts** (15 tests)
Tests structured logging system:
- Log levels (DEBUG, INFO, WARN, ERROR)
- Context logging
- Specialized methods
- Timestamp formatting

**Coverage**: 97.6% ✅

#### 3. **config.test.ts** (16 tests)
Tests configuration and validation:
- Video dimensions
- Codec settings
- Validation helpers

**Coverage**: 91.6% ✅

#### 4. **gpu-client.simple.test.ts** (13 tests)
Tests GPU client validation:
- Text/prompt validation
- Buffer validation
- File path validation

#### 5. **storage.test.ts** (25 tests)
Tests storage operations logic:
- Key generation
- Content type detection
- URL parsing
- S3 configuration

#### 6. **queue.test.ts** (22 tests)
Tests queue management:
- Job structures
- Priority calculation
- Retry logic
- Queue metrics

#### 7. **video.test.ts** (30 tests)
Tests video processing logic:
- Dimensions & aspect ratios
- FFmpeg commands
- FPS parsing
- Filter graphs

## 🧩 Mock Utilities

### GPU Server Mocks

```typescript
import {
  mockGPUHealthCheck,
  createMockAudioBuffer,
  createMockVideoBuffer,
  createMockImageBuffer,
} from './mocks/gpu-server.mock';

// Use in tests
const audio = createMockAudioBuffer(2); // 2 seconds
const video = createMockVideoBuffer(640, 480);
const image = createMockImageBuffer(1080, 1920);
```

### Global Test Utils

```typescript
// Create temp test file
const filePath = await global.testUtils.createTempFile('content', '.txt');

// Cleanup
await global.testUtils.cleanupTempFiles([filePath]);
```

## ✅ Test Patterns

### Error Testing
```typescript
import { ValidationError } from '@/lib/types';

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

### Async Testing
```typescript
it('should handle async operation', async () => {
  const result = await asyncFunction();
  expect(result).toBe('success');
});

it('should reject async operation', async () => {
  await expect(failingFunction()).rejects.toThrow();
});
```

### Mock Testing
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

## 📊 Coverage Reports

### View Coverage
```bash
# Generate HTML report
npm run test:coverage

# Open in browser
open coverage/index.html
```

### Current Coverage
```
lib/types.ts   → 100.0% ✅
lib/logger.ts  →  97.6% ✅
lib/config.ts  →  91.6% ✅
```

## 🐛 Debugging

### VSCode Debug Config
Add to `.vscode/launch.json`:
```json
{
  "type": "node",
  "request": "launch",
  "name": "Debug Vitest Tests",
  "runtimeExecutable": "npm",
  "runtimeArgs": ["run", "test:watch"],
  "console": "integratedTerminal"
}
```

### Debug Single Test
```bash
npx vitest run tests/unit/types.test.ts --reporter=verbose
```

## 📚 Best Practices

1. ✅ **Test Isolation**: Each test is independent
2. ✅ **Descriptive Names**: Use clear "should..." format
3. ✅ **AAA Pattern**: Arrange, Act, Assert
4. ✅ **Mock External Deps**: Don't hit real services
5. ✅ **Test Edge Cases**: Empty, null, undefined, extremes
6. ✅ **TypeScript**: Full type safety
7. ✅ **Fast Tests**: Mock expensive operations
8. ✅ **Behavior Over Implementation**: Test what, not how

## 🎯 Next Steps

### To Implement
- [ ] Integration tests for API routes
- [ ] Integration tests for storage
- [ ] Integration tests for queue
- [ ] Integration tests for worker
- [ ] E2E tests for full pipeline
- [ ] Performance benchmarks
- [ ] Visual regression tests

### To Improve
- [ ] Increase coverage to 90%+
- [ ] Add snapshot testing
- [ ] Add mutation testing
- [ ] Add contract testing
- [ ] CI/CD integration

## 🔗 Resources

- [Vitest Documentation](https://vitest.dev/)
- [Testing Best Practices](https://github.com/goldbergyoni/javascript-testing-best-practices)
- [Project Testing Docs](../docs/TESTING.md)
- [Test Summary](../TEST_SUMMARY.md)

## 💡 Tips

### Writing Good Tests
```typescript
// ❌ Bad: Unclear what's being tested
it('test function', () => {
  expect(fn()).toBe(true);
});

// ✅ Good: Clear intent
it('should return true for valid input', () => {
  const input = 'valid';
  const result = fn(input);
  expect(result).toBe(true);
});
```

### Testing Edge Cases
```typescript
it('should handle edge cases', () => {
  expect(fn('')).toBe(defaultValue);       // empty
  expect(fn('   ')).toBe(defaultValue);    // whitespace
  expect(fn(null)).toBe(defaultValue);     // null
  expect(fn(undefined)).toBe(defaultValue); // undefined
  expect(() => fn('A'.repeat(10000))).toThrow(); // extreme
});
```

### Grouping Related Tests
```typescript
describe('Video Processing', () => {
  describe('Format Validation', () => {
    it('should accept VERTICAL format', () => { /* ... */ });
    it('should accept HORIZONTAL format', () => { /* ... */ });
    it('should reject invalid format', () => { /* ... */ });
  });
  
  describe('Dimension Calculation', () => {
    it('should calculate 9:16 aspect ratio', () => { /* ... */ });
    it('should calculate 16:9 aspect ratio', () => { /* ... */ });
  });
});
```

---

**Happy Testing!** 🧪
