import { fetch } from 'expo-modules-core/fetch';

export const name = 'Fetch';

export function test({ describe, expect, it, beforeAll, beforeEach, afterEach, ...t }) {
  describe('Response types', () => {
    it('should support redirect and contain basic properties', async () => {
      const resp = await fetch('https://httpbin.org/redirect-to?url=https://httpbin.org/get');
      expect(resp.status).toBe(200);
      expect(resp.url).toBe('https://httpbin.org/get');
      expect(resp.ok).toBe(true);
    });

    it('should process json', async () => {
      const resp = await fetch('https://httpbin.org/get');
      const json = await resp.json();
      expect(json.url).toBe('https://httpbin.org/get');
    });

    it('should process text', async () => {
      const resp = await fetch('https://httpbin.org/xml');
      const xml = await resp.text();
      expect(xml).toContain(`<?xml version='1.0'`);
    });

    it('should process arrayBuffer', async () => {
      const resp = await fetch('https://httpbin.org/bytes/20');
      const buffer = await resp.arrayBuffer();
      expect(buffer.byteLength).toBe(20);
    });
  });

  describe('Request body', () => {
    it('should post with json', async () => {
      const resp = await fetch('https://httpbin.org/post', {
        headers: {
          'Content-Type': 'application/json',
        },
        method: 'POST',
        body: JSON.stringify({ foo: 'foo' }),
      });
      const json = await resp.json();
      expect(json.json).toEqual({ foo: 'foo' });
    });

    it('should post with x-www-form-urlencoded', async () => {
      const resp = await fetch('https://httpbin.org/post', {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        method: 'POST',
        body: 'foo=foo',
      });
      const json = await resp.json();
      expect(json.form).toEqual({ foo: 'foo' });
    });

    it('should post with FormData without files', async () => {
      const formData = new FormData();
      formData.append('foo', 'foo');
      const resp = await fetch('https://httpbin.org/post', {
        method: 'POST',
        body: formData,
      });
      const json = await resp.json();
      expect(json.form).toEqual({ foo: 'foo' });
      expect(json.headers['Content-Type'].startsWith('multipart/form-data; boundary=')).toBe(true);
    });

    it('should support gzip request', async () => {
      const body = '{"foo":"foo"}';
      const expectedBytesNumber = 29; // echo -n '{"foo":"foo"}' | gzip | wc -c
      const resp = await fetch('https://httpbin.org/anything', {
        method: 'POST',
        headers: {
          'Content-Encoding': 'gzip',
          'Content-Type': 'application/json',
        },
        body,
      });
      const json = await resp.json();
      expect(json.headers['Content-Encoding']).toBe('gzip');
      expect(json.headers['Content-Length']).toBe(String(expectedBytesNumber));
    });
  });

  describe('Headers', () => {
    it('should process request and response headers', async () => {
      const resp = await fetch('https://httpbin.org/get', {
        headers: {
          'X-Test': 'test',
        },
      });
      expect(resp.headers.get('Content-Type')).toBe('application/json');
      const json = await resp.json();
      expect(json.headers['X-Test']).toBe('test');
    });
  });

  describe('Cookies', () => {
    it('should include cookies when credentials are set to include (default case)', async () => {
      await fetch('https://httpbin.org/cookies/set?foo=bar');
      const resp = await fetch('https://httpbin.org/cookies');
      const json = await resp.json();
      expect(json.cookies.foo).toBe('bar');
    });

    it('should not include cookies when credentials are set to omit', async () => {
      await fetch('https://httpbin.org/cookies/set?foo=bar');
      const resp = await fetch('https://httpbin.org/cookies', {
        credentials: 'omit',
      });
      const json = await resp.json();
      expect(json.cookies).toEqual({});
    });
  });

  describe('Error handling', () => {
    it('should process 404', async () => {
      const resp = await fetch('https://httpbin.org/status/404');
      expect(resp.status).toBe(404);
      expect(resp.ok).toBe(false);
    });

    it('should abort request', async () => {
      const controller = new AbortController();
      setTimeout(() => controller.abort(), 500);
      let error: Error | null = null;
      try {
        await fetch('https://httpbin.org/delay/3', {
          signal: controller.signal,
        });
      } catch (e: unknown) {
        if (e instanceof Error) {
          error = e;
        }
      }
      expect(error).not.toBeNull();
    });
  });

  describe('Streaming', () => {
    it('should stream response', async () => {
      const resp = await fetch('https://httpbin.org/stream-bytes/512?chunk_size=10');
      const reader = resp.body.getReader();
      const chunks = [];
      while (true) {
        const { done, value } = await reader.read();
        if (done) {
          break;
        }
        chunks.push(value);
      }
      expect(chunks.length).toBeGreaterThan(1);
      const buffer = new Uint8Array(chunks.reduce((acc, chunk) => acc + chunk.length, 0));
      expect(buffer.length).toBe(512);
    });
  });
}
