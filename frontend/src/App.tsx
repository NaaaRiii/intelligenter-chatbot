import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom'
import ChatWithSelector from './ChatWithSelector'
import CustomerInsightDashboard from './CustomerInsightDashboard'
import FAQ from './FAQ'
import ExistingCustomerFAQ from './ExistingCustomerFAQ'

function App() {
  return (
    <Router>
      <Routes>
        <Route path="/chat" element={<ChatWithSelector />} />
        <Route path="/chat/new" element={<ChatWithSelector />} />
        <Route path="/dashboard" element={<CustomerInsightDashboard />} />
        <Route path="/faq" element={<FAQ />} />
        <Route path="/existing-faq" element={<ExistingCustomerFAQ />} />
        <Route path="/" element={<Navigate to="/chat" replace />} />
      </Routes>
    </Router>
  )
}

export default App
