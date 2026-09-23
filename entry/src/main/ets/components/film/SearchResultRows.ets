import { MovieBasicInfo } from '../../types/FilmModels';
import { AppTheme } from '../../common/constants/AppTheme';
import { Breakpoint } from '../../common/utils/Breakpoint';
import { SearchResultItem } from './SearchResultItem';

@Component
export struct SearchResultRows {
  @Prop list: MovieBasicInfo[] = [];
  @Prop widthBp: string = 'sm';
  onSelect: (film: MovieBasicInfo) => void = () => {};

  private listCols(): number {
    return Breakpoint.listLanes(this.widthBp);
  }

  private rowIds(): number[] {
    const rows = Math.ceil(this.list.length / this.listCols());
    return Array.from({ length: rows }, (_: Object, i: number) => i);
  }

  private rowFilms(row: number): MovieBasicInfo[] {
    const cols = this.listCols();
    return this.list.slice(row * cols, row * cols + cols);
  }

  private rowFillers(row: number): number[] {
    const missing = Math.max(0, this.listCols() - this.rowFilms(row).length);
    return Array.from({ length: missing }, (_: Object, i: number) => i);
  }

  @Builder
  filmRow(row: number) {
    Row({ space: AppTheme.SPACE_LG }) {
      ForEach(this.rowFilms(row), (film: MovieBasicInfo) => {
        SearchResultItem({
          film: film,
          onSelect: (selected: MovieBasicInfo) => {
            this.onSelect(selected);
          }
        })
          .layoutWeight(1)
      }, (film: MovieBasicInfo) => `${film.sourceId}_${film.id}_${film.sourceMid}`)

      ForEach(this.rowFillers(row), (idx: number) => {
        Blank()
          .layoutWeight(1)
      }, (idx: number) => `filler_${row}_${idx}`)
    }
    .width('100%')
  }

  build() {
    Column({ space: AppTheme.SPACE_MD }) {
      ForEach(this.rowIds(), (row: number) => {
        this.filmRow(row)
      }, (row: number) => `row_${this.listCols()}_${row}_${this.list[row * this.listCols()]?.id}`)
    }
    .width('100%')
  }
}
