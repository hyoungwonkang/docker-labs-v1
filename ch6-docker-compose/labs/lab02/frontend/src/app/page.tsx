"use client";

import { useState, useEffect } from "react";

export default function Home() {
  const [lang, setLang] = useState("ko");
  const [greeting, setGreeting] = useState("");

  useEffect(() => {
    // 정적 export에서는 runtime에 API URL을 결정
    const apiUrl = process.env.NEXT_PUBLIC_API_URL || "http://localhost:8080";
    
    fetch(`${apiUrl}/greeting?lang=${lang}`)
      .then((res) => {
        if (!res.ok) {
          throw new Error(`HTTP error! status: ${res.status}`);
        }
        return res.text();
      })
      .then(setGreeting)
      .catch(() => setGreeting("API 오류"));
  }, [lang]);

  return (
    <main style={{ padding: 40 }}>
      <h1>Hello World</h1>
      <select value={lang} onChange={(e) => setLang(e.target.value)}>
        <option value="ko">한국어</option>
        <option value="en">English</option>
        <option value="ja">日本語</option>
      </select>
      <div style={{ marginTop: 24, fontSize: 32 }}>{greeting}</div>
    </main>
  );
}
