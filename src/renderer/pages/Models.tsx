const MODELS = [
  { name: 'Qwen3-30B-A3B', desc: 'MoE · 128K · 日常全能', mem: '32 GB', badge: 'badge-fixed', label: '常驻' },
  { name: 'bge-m3', desc: '多语言嵌入 · RAG 检索', mem: '1.5 GB', badge: 'badge-fixed', label: '常驻' },
  { name: 'ModernBERT-reranker', desc: 'RAG 重排序', mem: '0.5 GB', badge: 'badge-fixed', label: '常驻' },
  { name: 'Qwen3.6-27B', desc: 'Dense · 代码 · 结构化输出', mem: '35 GB', badge: 'badge-ondemand', label: '按需' },
  { name: 'Qwen3-32B', desc: 'Dense 旗舰 · 深度推理', mem: '41 GB', badge: 'badge-ondemand', label: '按需' },
  { name: 'mlx-whisper large-v3', desc: 'ASR · 视频字幕', mem: '~3 GB', badge: 'badge-unload', label: '用完即卸' },
  { name: 'FLUX.1-schnell', desc: '文生图 · ~20s/张', mem: '16 GB', badge: 'badge-unload', label: '用完即卸' },
  { name: 'LTX-2.3 Distilled Q4', desc: '短视频生成', mem: '19 GB', badge: 'badge-unload', label: '用完即卸' },
  { name: 'CosyVoice2-0.5B', desc: '中文语音克隆 · TTS', mem: '3 GB', badge: 'badge-unload', label: '用完即卸' },
]

export default function ModelsPage() {
  return (
    <div className="content">
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
        <div className="page-title">模型管理</div>
        <button className="btn btn-primary" style={{ fontSize: 12 }}>+ 下载模型</button>
      </div>
      <div className="page-sub">64 GB 统一内存 · oMLX 管理主力 LLM · Ollama 备选</div>
      <div className="models-list">
        {MODELS.map(m => (
          <div key={m.name} className="model-row">
            <div className="model-info">
              <h4>{m.name}</h4>
              <p>{m.desc}</p>
            </div>
            <span className={`model-badge ${m.badge}`}>{m.label}</span>
            <span className="model-mem">{m.mem}</span>
          </div>
        ))}
      </div>
    </div>
  )
}
