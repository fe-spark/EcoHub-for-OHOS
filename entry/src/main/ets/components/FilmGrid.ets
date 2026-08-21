import { MovieBasicInfo } from '../model/FilmModels';
import { FilmCard } from './FilmCard';

@Component
export struct FilmGrid {
  @Prop films: MovieBasicInfo[] = [];
  @Prop columns: number = 3;
  @Prop nestedRefresh: boolean = false;
  @Prop embedInScroll: boolean = false;
  onReachEnd?: () => void;
  onClickFilm?: (film: MovieBasicInfo) => void;

  private onIndexChange(_first: number, last: number): void {
    if (this.onReachEnd && last >= this.films.length - 3) {
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
    .columnsTemplate(this.columns === 3 ? '1fr 1fr 1fr' : '1fr 1fr')
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
