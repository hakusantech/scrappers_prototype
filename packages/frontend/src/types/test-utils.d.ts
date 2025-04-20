import '@testing-library/jest-dom'

declare module '@testing-library/jest-dom' {
  export interface Matchers<R> {
    toBeInTheDocument(): R
    toHaveTextContent(text: string): R
    toHaveClass(className: string): R
  }
}