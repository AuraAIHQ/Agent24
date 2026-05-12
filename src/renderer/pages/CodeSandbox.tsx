import { useState, useEffect, useRef } from 'react'

interface StatusResult {
  available: boolean
  error?: string
}

interface RunResult {
  ok: boolean
  output?: string
  error?: string
}

const PLACEHOLDER = `# 在这里输入 Python 代码
import sys
print(f"Python {sys.version}")
print("Hello from BoxLite sandbox!")
`

export default function CodeSandboxPage() {
  const [code, setCode] = useState(PLACEHOLDER)
  const [output, setOutput] = useState('')
  const [running, setRunning] = useState(false)
  const [status, setStatus] = useState<StatusResult | null>(null)
  const abortRef = useRef(false)

  useEffect(() => {
    void window.agent24.backendProxy({ method: 'GET', path: '/api/codebox/status' })
      .then((res) => {
        if (res.ok) setStatus(res.data as StatusResult)
      })
      .catch(() => setStatus({ available: false, error: 'Backend unavailable' }))
  }, [])

  async function run() {
    if (running) return
    setRunning(true)
    setOutput('Running…')
    abortRef.current = false
    try {
      const res = await window.agent24.backendProxy({
        method: 'POST',
        path: '/api/codebox/run',
        body: { code },
      })
      if (abortRef.current) return
      const data = res.data as RunResult
      if (data.ok) {
        setOutput(data.output ?? '(no output)')
      } else {
        setOutput(`Error: ${data.error ?? 'unknown'}`)
      }
    } catch (err) {
      if (!abortRef.current) setOutput(`Error: ${String(err)}`)
    } finally {
      setRunning(false)
    }
  }

  const available = status?.available ?? true

  return (
    <div className="content">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
        <div className="page-title">Python 沙箱</div>
        <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
          {status !== null && (
            <span style={{ fontSize: 11, color: available ? 'var(--accent)' : 'var(--muted)' }}>
              {available ? '● BoxLite 就绪' : '● BoxLite 不可用'}
            </span>
          )}
          <button
            className="btn btn-primary"
            style={{ fontSize: 12 }}
            onClick={() => void run()}
            disabled={running || !available}
          >
            {running ? '运行中…' : '▶ 运行'}
          </button>
        </div>
      </div>
      <div className="page-sub">BoxLite 隔离沙箱 · 每次运行独立容器 · 支持 Python 3</div>

      {status !== null && !available && (
        <div style={{ fontSize: 12, color: '#e57373', marginBottom: 12, padding: '8px 12px', background: 'var(--surface2)', borderRadius: 8 }}>
          BoxLite 原生绑定不可用：{status.error ?? '未知错误'}
        </div>
      )}

      <div style={{ display: 'flex', flexDirection: 'column', gap: 12, flex: 1 }}>
        <div>
          <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--muted)', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            代码
          </div>
          <textarea
            value={code}
            onChange={(e) => setCode(e.target.value)}
            spellCheck={false}
            style={{
              width: '100%',
              minHeight: 200,
              fontFamily: 'monospace',
              fontSize: 13,
              lineHeight: 1.6,
              padding: '10px 12px',
              background: 'var(--surface2)',
              color: 'var(--text)',
              border: '1px solid var(--border)',
              borderRadius: 8,
              resize: 'vertical',
              boxSizing: 'border-box',
            }}
          />
        </div>

        <div>
          <div style={{ fontSize: 11, fontWeight: 600, color: 'var(--muted)', marginBottom: 6, textTransform: 'uppercase', letterSpacing: '0.05em' }}>
            输出
          </div>
          <pre
            style={{
              minHeight: 100,
              padding: '10px 12px',
              background: 'var(--surface2)',
              border: '1px solid var(--border)',
              borderRadius: 8,
              fontFamily: 'monospace',
              fontSize: 12,
              whiteSpace: 'pre-wrap',
              wordBreak: 'break-all',
              color: output.startsWith('Error:') ? '#e57373' : 'var(--text)',
              margin: 0,
            }}
          >
            {output || '点击"运行"执行代码'}
          </pre>
        </div>
      </div>
    </div>
  )
}
