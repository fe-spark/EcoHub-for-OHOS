import { AppTheme } from '../../common/constants/AppTheme';
import { NavUtil } from '../../common/utils/NavUtil';
import { common } from '@kit.AbilityKit';

export interface MarkdownSpan {
  text: string;
  isBold?: boolean;
  isItalic?: boolean;
  isCode?: boolean;
  linkUrl?: string;
  isImage?: boolean;
  imageUrl?: string;
}

export interface MarkdownBlock {
  id: string;
  type: 'h1' | 'h2' | 'h3' | 'h4' | 'list' | 'ordered-list' | 'blockquote' | 'codeblock' | 'hr' | 'paragraph' | 'empty';
  spans: MarkdownSpan[];
  paragraphs?: MarkdownSpan[][];
  index?: number;
  indent?: number;
  rawContent?: string;
}

function resolveBadgeUrl(raw: string): string {
  if (raw.indexOf('img.shields.io') >= 0) {
    let url = raw.replace('img.shields.io', 'raster.shields.io');
    if (url.toLowerCase().startsWith('http://')) {
      url = `https://${url.substring(7)}`;
    }
    const qIdx = url.indexOf('?');
    const base = qIdx >= 0 ? url.substring(0, qIdx) : url;
    const query = qIdx >= 0 ? url.substring(qIdx) : '';
    if (base.endsWith('.svg')) {
      return `${base.substring(0, base.length - 4)}.png${query}`;
    } else if (!base.endsWith('.png')) {
      return `${base}.png${query}`;
    }
    return url;
  }
  return raw;
}

function isSafeLinkUrl(url: string): boolean {
  const lower = url.trim().toLowerCase();
  return lower.startsWith('https://') || lower.startsWith('http://') || lower.startsWith('mailto:');
}

function isSafeImageUrl(url: string): boolean {
  return url.trim().toLowerCase().startsWith('https://');
}

function parseInlineSpans(text: string): MarkdownSpan[] {
  const spans: MarkdownSpan[] = [];
  if (!text) {
    return spans;
  }

  const tokenRegex = /(\[!\[.*?\]\([^\s)]+\)\]\([^\s)]+\)|!\[.*?\]\([^\s)]+\)|\[.*?\]\([^\s)]+\)|\*\*.*?\*\*|`.*?`|\*.*?\*)/;
  let remaining = text;

  while (remaining.length > 0) {
    const match = remaining.match(tokenRegex);
    if (!match || match.index === undefined) {
      spans.push({ text: remaining });
      break;
    }

    const matchIndex = match.index;
    if (matchIndex > 0) {
      spans.push({ text: remaining.slice(0, matchIndex) });
    }

    const token = match[0];
    if (token.startsWith('[![') && token.endsWith(')')) {
      const badgeMatch = token.match(/^\[!\[(.*?)\]\(([^\s)]+)\)\]\(([^\s)]+)\)$/);
      if (badgeMatch) {
        spans.push({ text: badgeMatch[1], isImage: true, imageUrl: resolveBadgeUrl(badgeMatch[2]), linkUrl: badgeMatch[3] });
      } else {
        spans.push({ text: token });
      }
    } else if (token.startsWith('![') && token.endsWith(')')) {
      const imgMatch = token.match(/^!\[(.*?)\]\(([^\s)]+)\)$/);
      if (imgMatch) {
        spans.push({ text: imgMatch[1], isImage: true, imageUrl: resolveBadgeUrl(imgMatch[2]) });
      } else {
        spans.push({ text: token });
      }
    } else if (token.startsWith('[') && token.includes('](') && token.endsWith(')')) {
      const splitIdx = token.indexOf('](');
      const linkText = token.slice(1, splitIdx);
      const linkUrl = token.slice(splitIdx + 2, -1);
      spans.push({ text: linkText || linkUrl, linkUrl: linkUrl });
    } else if (token.startsWith('**') && token.endsWith('**') && token.length >= 4) {
      spans.push({ text: token.slice(2, -2), isBold: true });
    } else if (token.startsWith('`') && token.endsWith('`') && token.length >= 2) {
      spans.push({ text: token.slice(1, -1), isCode: true });
    } else if (token.startsWith('*') && token.endsWith('*') && token.length >= 2) {
      spans.push({ text: token.slice(1, -1), isItalic: true });
    } else {
      spans.push({ text: token });
    }

    remaining = remaining.slice(matchIndex + token.length);
  }

  return spans;
}

function parseMarkdownBlocks(content: string): MarkdownBlock[] {
  const blocks: MarkdownBlock[] = [];
  if (!content) {
    return blocks;
  }
  const lines = content.split('\n');
  let i = 0;
  let blockId = 0;

  while (i < lines.length) {
    const rawLine = lines[i];
    const trimmed = rawLine.trim();

    if (!trimmed) {
      blocks.push({ id: `b_${blockId++}`, type: 'empty', spans: [] });
      i++;
      continue;
    }

    // 分割线 --- 或 ***
    if (/^(\-{3,}|\*{3,}|_{3,})$/.test(trimmed)) {
      blocks.push({ id: `b_${blockId++}`, type: 'hr', spans: [] });
      i++;
      continue;
    }

    // 代码块 ```
    if (trimmed.startsWith('```')) {
      i++;
      const codeLines: string[] = [];
      while (i < lines.length && !lines[i].trim().startsWith('```')) {
        codeLines.push(lines[i]);
        i++;
      }
      if (i < lines.length && lines[i].trim().startsWith('```')) {
        i++;
      }
      blocks.push({
        id: `b_${blockId++}`,
        type: 'codeblock',
        spans: [],
        rawContent: codeLines.join('\n')
      });
      continue;
    }

    // 连续引用块合并
    if (trimmed.startsWith('>')) {
      const quoteParagraphs: MarkdownSpan[][] = [];
      while (i < lines.length && lines[i].trim().startsWith('>')) {
        const lineContent = lines[i].trim().replace(/^>\s?/, '').trim();
        if (lineContent) {
          quoteParagraphs.push(parseInlineSpans(lineContent));
        }
        i++;
      }

      blocks.push({
        id: `b_${blockId++}`,
        type: 'blockquote',
        spans: quoteParagraphs.length > 0 ? quoteParagraphs[0] : [],
        paragraphs: quoteParagraphs
      });
      continue;
    }

    // 标题
    if (trimmed.startsWith('#### ')) {
      blocks.push({ id: `b_${blockId++}`, type: 'h4', spans: parseInlineSpans(trimmed.slice(5)) });
      i++;
      continue;
    }
    if (trimmed.startsWith('### ')) {
      blocks.push({ id: `b_${blockId++}`, type: 'h3', spans: parseInlineSpans(trimmed.slice(4)) });
      i++;
      continue;
    }
    if (trimmed.startsWith('## ')) {
      blocks.push({ id: `b_${blockId++}`, type: 'h2', spans: parseInlineSpans(trimmed.slice(3)) });
      i++;
      continue;
    }
    if (trimmed.startsWith('# ')) {
      blocks.push({ id: `b_${blockId++}`, type: 'h1', spans: parseInlineSpans(trimmed.slice(2)) });
      i++;
      continue;
    }

    // 有序列表 1. 2.
    const orderedMatch = trimmed.match(/^(\d+)\.\s+(.*)$/);
    if (orderedMatch) {
      const num = parseInt(orderedMatch[1], 10);
      const text = orderedMatch[2];
      const leadingSpaces = rawLine.length - rawLine.trimStart().length;
      const indentLevel = Math.min(3, Math.floor(leadingSpaces / 2));
      blocks.push({
        id: `b_${blockId++}`,
        type: 'ordered-list',
        index: num,
        spans: parseInlineSpans(text),
        indent: indentLevel
      });
      i++;
      continue;
    }

    // 无序列表 - * +
    if (/^[\-\*\+]\s+/.test(trimmed)) {
      const listContent = trimmed.replace(/^[\-\*\+]\s+/, '');
      const leadingSpaces = rawLine.length - rawLine.trimStart().length;
      const indentLevel = Math.min(3, Math.floor(leadingSpaces / 2));
      blocks.push({
        id: `b_${blockId++}`,
        type: 'list',
        spans: parseInlineSpans(listContent),
        indent: indentLevel
      });
      i++;
      continue;
    }

    // 普通段落
    blocks.push({
      id: `b_${blockId++}`,
      type: 'paragraph',
      spans: parseInlineSpans(trimmed)
    });
    i++;
  }

  return blocks;
}

@Component
export struct MarkdownView {
  @Prop content: string = '';
  @Prop fontSize: number = 14;
  @Prop fontColor: ResourceColor = AppTheme.TEXT_SECONDARY;

  private handleOpenLink(url: string): void {
    if (!url || !isSafeLinkUrl(url)) {
      return;
    }
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      NavUtil.openBrowser(ctx, url);
    } catch (_e) {}
  }

  @Builder
  buildSpan(span: MarkdownSpan, overrideColor?: ResourceColor) {
    if (span.isImage && span.imageUrl && isSafeImageUrl(span.imageUrl)) {
      ImageSpan(span.imageUrl)
        .height(20)
        .objectFit(ImageFit.Contain)
        .verticalAlign(ImageSpanAlignment.CENTER)
        .margin({ right: 4, bottom: 2 })
        .onClick(() => {
          if (span.linkUrl) {
            this.handleOpenLink(span.linkUrl);
          }
        })
    } else if (span.linkUrl && isSafeLinkUrl(span.linkUrl)) {
      Span(span.text)
        .fontColor(AppTheme.ACCENT)
        .decoration({ type: TextDecorationType.Underline, color: AppTheme.ACCENT })
        .fontSize(this.fontSize)
        .onClick(() => {
          this.handleOpenLink(span.linkUrl || '');
        })
    } else if (span.isBold) {
      Span(span.text)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppTheme.TEXT_PRIMARY)
        .fontSize(this.fontSize)
    } else if (span.isCode) {
      Span(` ${span.text} `)
        .fontColor(AppTheme.ACCENT)
        .fontFamily('monospace')
        .fontSize(Math.max(11, this.fontSize - 1))
    } else if (span.isItalic) {
      Span(span.text)
        .fontStyle(FontStyle.Italic)
        .fontColor(overrideColor || this.fontColor)
        .fontSize(this.fontSize)
    } else {
      Span(span.text)
        .fontColor(overrideColor || this.fontColor)
        .fontSize(this.fontSize)
    }
  }

  build() {
    Column() {
      ForEach(parseMarkdownBlocks(this.content), (block: MarkdownBlock) => {
        if (block.type === 'h1' || block.type === 'h2' || block.type === 'h3' || block.type === 'h4') {
          Text() {
            ForEach(block.spans, (span: MarkdownSpan) => {
              Span(span.text)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppTheme.TEXT_PRIMARY)
                .fontSize(
                  block.type === 'h1' ? this.fontSize + 3 :
                  block.type === 'h2' ? this.fontSize + 2 :
                  block.type === 'h3' ? this.fontSize + 1 : this.fontSize
                )
            })
          }
          .width('100%')
          .lineHeight(this.fontSize * 1.5)
          .margin({ top: 10, bottom: 4 })
        } else if (block.type === 'hr') {
          Column()
            .width('100%')
            .height(1)
            .backgroundColor('rgba(255, 255, 255, 0.08)')
            .margin({ top: 10, bottom: 10 })
        } else if (block.type === 'codeblock') {
          Scroll() {
            Text(block.rawContent || '')
              .fontColor(AppTheme.TEXT_PRIMARY)
              .fontSize(Math.max(11, this.fontSize - 2))
              .fontFamily('monospace')
              .lineHeight(this.fontSize * 1.45)
          }
          .scrollable(ScrollDirection.Horizontal)
          .width('100%')
          .padding(8)
          .backgroundColor('rgba(255, 255, 255, 0.04)')
          .border({ width: 1, color: 'rgba(255, 255, 255, 0.08)' })
          .borderRadius(AppTheme.RADIUS_SM)
          .margin({ top: 4, bottom: 8 })
        } else if (block.type === 'list') {
          Row() {
            Text(block.indent && block.indent > 0 ? '◦ ' : '• ')
              .fontColor(block.indent && block.indent > 0 ? AppTheme.TEXT_MUTED : AppTheme.ACCENT)
              .fontSize(block.indent && block.indent > 0 ? this.fontSize - 2 : this.fontSize)
              .lineHeight(this.fontSize * 1.65)
              .margin({ right: 6 })
            Text() {
              ForEach(block.spans, (span: MarkdownSpan) => {
                this.buildSpan(span)
              })
            }
            .layoutWeight(1)
            .lineHeight(this.fontSize * 1.65)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ left: (block.indent || 0) * 14 })
          .margin({ bottom: 4 })
        } else if (block.type === 'ordered-list') {
          Row() {
            Text(`${block.index || 1}. `)
              .fontColor(AppTheme.ACCENT)
              .fontSize(this.fontSize)
              .lineHeight(this.fontSize * 1.65)
              .margin({ right: 4 })
            Text() {
              ForEach(block.spans, (span: MarkdownSpan) => {
                this.buildSpan(span)
              })
            }
            .layoutWeight(1)
            .lineHeight(this.fontSize * 1.65)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)
          .padding({ left: (block.indent || 0) * 14 })
          .margin({ bottom: 4 })
        } else if (block.type === 'blockquote') {
          Column() {
            ForEach(block.paragraphs && block.paragraphs.length > 0 ? block.paragraphs : [block.spans], (pSpans: MarkdownSpan[], pIdx: number) => {
              Text() {
                ForEach(pSpans, (span: MarkdownSpan) => {
                  this.buildSpan(span, AppTheme.TEXT_MUTED)
                })
              }
              .width('100%')
              .lineHeight(this.fontSize * 1.55)
              .margin({ bottom: pIdx < ((block.paragraphs?.length || 1) - 1) ? 4 : 0 })
            })
          }
          .width('100%')
          .padding({ left: 10, right: 6, top: 6, bottom: 6 })
          .border({
            width: { left: 3 },
            color: { left: AppTheme.ACCENT }
          })
          .borderRadius({ topRight: AppTheme.RADIUS_SM, bottomRight: AppTheme.RADIUS_SM })
          .backgroundColor('rgba(255, 255, 255, 0.04)')
          .margin({ top: 6, bottom: 8 })
          .alignItems(HorizontalAlign.Start)
        } else if (block.type === 'empty') {
          Column().height(6)
        } else {
          Text() {
            ForEach(block.spans, (span: MarkdownSpan) => {
              this.buildSpan(span)
            })
          }
          .width('100%')
          .lineHeight(this.fontSize * 1.65)
          .margin({ bottom: 8 })
        }
      }, (block: MarkdownBlock) => block.id)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
