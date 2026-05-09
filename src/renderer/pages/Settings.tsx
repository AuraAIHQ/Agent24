export default function SettingsPage() {
  return (
    <div className="content">
      <div className="page-title">设置</div>
      <div className="page-sub">配置 LLM 运行时、后端服务和应用偏好</div>

      <div className="settings-section">
        <h3>LLM 运行时</h3>
        <div className="setting-row">
          <div>
            <label>推理引擎</label>
            <p>选择本地推理后端，影响所有 AI 能力模块</p>
          </div>
          <select defaultValue="omlx">
            <option value="omlx">oMLX（Apple Silicon 推荐）</option>
            <option value="ollama">Ollama</option>
            <option value="lmstudio">LM Studio</option>
            <option value="remote">远程 API（OpenAI 兼容）</option>
          </select>
        </div>
        <div className="setting-row">
          <div>
            <label>服务地址</label>
            <p>推理服务的 HTTP 端点</p>
          </div>
          <input type="text" defaultValue="http://localhost:8000" style={{ width: 240 }} />
        </div>
        <div className="setting-row">
          <div>
            <label>默认模型</label>
            <p>对话和通用任务使用的模型</p>
          </div>
          <select defaultValue="qwen3-30b">
            <option value="qwen3-30b">Qwen3-30B-A3B（推荐）</option>
            <option value="qwen3-32b">Qwen3-32B</option>
            <option value="qwen3.6-27b">Qwen3.6-27B</option>
          </select>
        </div>
      </div>

      <div className="settings-section">
        <h3>后端服务</h3>
        <div className="setting-row">
          <div>
            <label>后台 Daemon 端口</label>
            <p>Agent24 内部服务监听端口</p>
          </div>
          <input type="text" defaultValue="8765" style={{ width: 80 }} />
        </div>
      </div>

      <div className="settings-section">
        <h3>界面</h3>
        <div className="setting-row">
          <div>
            <label>语言</label>
            <p>界面显示语言</p>
          </div>
          <select defaultValue="zh">
            <option value="zh">中文</option>
            <option value="en">English</option>
          </select>
        </div>
      </div>

      <div style={{ marginTop: 8 }}>
        <button className="btn btn-primary">保存设置</button>
        {' '}
        <button className="btn btn-ghost" style={{ marginLeft: 8 }}>重置默认</button>
      </div>
    </div>
  )
}
