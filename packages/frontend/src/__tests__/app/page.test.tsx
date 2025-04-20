import { render, screen } from '@testing-library/react'
import Home from '../../app/page'

describe('Home', () => {
  it('renders the welcome message', () => {
    render(<Home />)
    
    // ヘッダーのテスト
    const header = screen.getByRole('heading', {
      name: /Resource Management System/i,
      level: 1
    })
    expect(header).toBeInTheDocument()
    
    // ウェルカムメッセージのテスト
    const welcomeText = screen.getByText(
      /Welcome to the Scrappers Resource Management System/i
    )
    expect(welcomeText).toBeInTheDocument()
  })
})