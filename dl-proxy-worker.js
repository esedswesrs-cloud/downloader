export default {
  async fetch(request) {
    const url = new URL(request.url);
    const target = url.searchParams.get("url");
    const filename = url.searchParams.get("filename") || "download.mp4";
    if (!target) return new Response("missing url", {status: 400});
    try {
      const r = await fetch(target, {headers: {"User-Agent": "Mozilla/5.0"}});
      if (!r.ok) return new Response("upstream "+r.status, {status: 502});
      const h = new Headers(r.headers);
      h.set("Content-Disposition", 'attachment; filename="'+filename.replace(/"/g,"")+'"');
      h.set("Access-Control-Allow-Origin", "*");
      return new Response(r.body, {status: r.status, headers: h});
    } catch(e) {
      return new Response("fetch failed", {status: 502});
    }
  }
};
