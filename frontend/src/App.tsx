import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import Chatbot from './Chatbot'
import CustomerInsightDashboard from './CustomerInsightDashboard'

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/chat" element={<Chatbot />} />
        <Route path="/dashboard" element={<CustomerInsightDashboard />} />
        <Route path="/" element={<Navigate to="/chat" replace />} />
      </Routes>
    </Router>
  )
}

export default App
