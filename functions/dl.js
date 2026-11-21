export async function onRequest({request}) {
  const url = new URL(request.url);
  const target = url.searchParams.get("url");
  const filename = (url.searchParams.get("filename") || "video.mp4").replace(/["\r\n]/g, "");
  if (!target || !/^https?:\/\//i.test(target)) {
    return new Response("missing url", {status: 400});
  }
  const r = await fetch(target, {headers: {"User-Agent": "Mozilla/5.0"}});
  if (!r.ok) return new Response("upstream error", {status: 502});
  const h = new Headers(r.headers);
  h.set("Content-Disposition", `attachment; filename="${filename}"`);
  return new Response(r.body, {status: 200, headers: h});
}
