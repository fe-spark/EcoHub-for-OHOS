export class QueryParams {
  private keys: string[] = [];
  private values: string[] = [];

  set(key: string, value: string | number | undefined | null): QueryParams {
    if (value === undefined || value === null) {
      return this;
    }
    const text = `${value}`.trim();
    if (key.startsWith('_') || text === '') {
      return this;
    }
    this.keys.push(key);
    this.values.push(text);
    return this;
  }

  toQuery(): string {
    const parts: string[] = [];
    for (let i = 0; i < this.keys.length; i++) {
      parts.push(`${encodeURIComponent(this.keys[i])}=${encodeURIComponent(this.values[i])}`);
    }
    return parts.join('&');
  }

  isEmpty(): boolean {
    return this.keys.length === 0;
  }
}
