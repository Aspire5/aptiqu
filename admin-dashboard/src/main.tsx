import { lazy, StrictMode, Suspense } from 'react'
import { createRoot } from 'react-dom/client'

// Separate entry chunks: public visitors never mount admin auth or load admin CSS.
const isPublic = window.location.pathname === '/'
const Page = isPublic
  ? lazy(() => import('./public/PublicLanding'))
  : lazy(() => import('./App'))

if (isPublic) document.documentElement.dataset.aptiquPublic = ''
else document.title = 'AptiQu Admin Console'

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <Suspense fallback={<div role="status" style={{ minHeight: '100vh', background: isPublic ? '#0F111A' : '#f0f2f5', color: isPublic ? '#E8E7F0' : '#344767', padding: 24 }}>Loading AptiQu…</div>}>
      <Page />
    </Suspense>
  </StrictMode>,
)
