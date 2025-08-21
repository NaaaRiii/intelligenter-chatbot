import { describe, it, expect } from 'vitest'

describe('Example Test Suite', () => {
  it('should pass a basic test', () => {
    expect(1 + 1).toBe(2)
  })

  it('should work with TypeScript', () => {
    const message: string = 'Hello TypeScript'
    expect(message).toContain('TypeScript')
  })

  it('should handle arrays', () => {
    const numbers = [1, 2, 3, 4, 5]
    expect(numbers).toHaveLength(5)
    expect(numbers).toContain(3)
  })
})