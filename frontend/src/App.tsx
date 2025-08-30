import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import ChatWithSelector from './ChatWithSelector'
import CustomerInsightDashboard from './CustomerInsightDashboard'

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/chat" element={<ChatWithSelector />} />
        <Route path="/dashboard" element={<CustomerInsightDashboard />} />
        <Route path="/" element={<Navigate to="/chat" replace />} />
      </Routes>
    </Router>
  )
}

export default App
