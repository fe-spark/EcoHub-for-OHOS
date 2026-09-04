import { MovieBasicInfo } from '../model/FilmModels';
import { Breakpoint } from '../common/utils/Breakpoint';
import { FilmCard } from './FilmCard';

@Component
export struct FilmGrid {
  @Prop films: MovieBasicInfo[] = [];
  @Prop columns: number = 0;
  @Prop nestedRefresh: boolean = false;
  @Prop embedInScroll: boolean = false;
  onReachEnd?: () => void;
  onClickFilm?: (film: MovieBasicInfo) => void;
  @StorageLink('WIDTH_BP') private widthBp: string = 'sm';

  private resolvedCols(): number {
    return this.columns > 0 ? this.columns : Breakpoint.gridCols(this.widthBp);
  }

  private onIndexChange(_first: number, last: number): void {
    if (this.onReachEnd && last >= this.films.length - this.resolvedCols()) {
      this.onReachEnd();
    }
  }

  @Builder
  filmItems() {
    ForEach(this.films, (film: MovieBasicInfo) => {
      GridItem() {
        FilmCard({ film: film, onClickCard: this.onClickFilm })
          .width('100%')
      }
    }, (film: MovieBasicInfo) => `${film.id}`)
  }

  build() {
    Grid() {
      this.filmItems()
    }
    .columnsTemplate(Breakpoint.columnsTemplate(this.resolvedCols()))
    .columnsGap(8)
    .rowsGap(12)
    .width('100%')
    .scrollBar(BarState.Off)
    .edgeEffect(this.embedInScroll || this.nestedRefresh ? EdgeEffect.None : EdgeEffect.Spring)
    .nestedScroll({
      scrollForward: NestedScrollMode.SELF_FIRST,
      scrollBackward: NestedScrollMode.SELF_FIRST
    })
    .onScrollIndex((first: number, last: number) => this.onIndexChange(first, last))
  }
}
