/** 筛选条件按标签行的键收口。v2 回写 Category，v3 回写 category，不能两套一起再请求。 */
export class FilterParamFold {
  keys: string[] = [];
  values: string[] = [];
}

export class FilterParams {
  static canonical(key: string): string {
    switch (key) {
      case 'category':
      case 'Category':
      case 'cid':
      case 'Cid':
        return 'Category';
      case 'plot':
      case 'Plot':
        return 'Plot';
      case 'area':
      case 'Area':
        return 'Area';
      case 'language':
      case 'Language':
        return 'Language';
      case 'year':
      case 'Year':
        return 'Year';
      case 'sort':
      case 'Sort':
        return 'Sort';
      case 'pid':
      case 'Pid':
        return 'Pid';
      default:
        return key;
    }
  }

  static isPid(key: string): boolean {
    return FilterParams.canonical(key) === 'Pid';
  }

  /** 同一维只留标签行用的键。已有规范键时不用别名覆盖。 */
  static fold(keys: string[], values: string[]): FilterParamFold {
    const out = new FilterParamFold();
    for (let i = 0; i < keys.length; i++) {
      const raw = keys[i];
      if (FilterParams.isPid(raw)) {
        continue;
      }
      const value = (i < values.length ? values[i] : '').trim();
      if (!value) {
        continue;
      }
      const key = FilterParams.canonical(raw);
      const index = out.keys.indexOf(key);
      if (index < 0) {
        out.keys.push(key);
        out.values.push(value);
      } else if (raw === key) {
        out.values[index] = value;
      }
    }
    return out;
  }

  /** 接口回写并进已选条件。空值取消这一维。Pid 不是筛选项。 */
  static applyEcho(selectedKeys: string[], selectedValues: string[], echoKeys: string[], echoValues: string[]): FilterParamFold {
    const next = FilterParams.fold(selectedKeys, selectedValues);
    for (let i = 0; i < echoKeys.length; i++) {
      const raw = echoKeys[i];
      if (FilterParams.isPid(raw)) {
        continue;
      }
      const key = FilterParams.canonical(raw);
      const value = (i < echoValues.length ? echoValues[i] : '').trim();
      const index = next.keys.indexOf(key);
      if (!value) {
        if (index >= 0) {
          next.keys.splice(index, 1);
          next.values.splice(index, 1);
        }
        continue;
      }
      if (index >= 0) {
        next.values[index] = value;
      } else {
        next.keys.push(key);
        next.values.push(value);
      }
    }
    return next;
  }
}
