import { MovieBasicInfo } from '../../types/FilmModels';
import { FilmGrid } from './FilmGrid';
import { LoadingView } from '../common/LoadingView';
import { EmptyState } from '../common/EmptyState';

@Component
export struct LivePlayRelatedView {
  @Prop relateLoading: boolean = false;
  @Prop related: MovieBasicInfo[] = [];
  @Prop columns: number = 3;
  onOpenRelated?: (film: MovieBasicInfo) => void;

  build() {
    Column() {
      if (this.relateLoading) {
        LoadingView({ label: '加载同类推荐' })
      } else if (this.related.length === 0) {
        EmptyState({ title: '暂无同类推荐', subtitle: '当前采集源该分类下暂无其它片源', icon: $r('sys.symbol.film') })
      } else {
        FilmGrid({
          films: this.related,
          columns: this.columns,
          onClickFilm: (film: MovieBasicInfo) => {
            if (this.onOpenRelated) {
              this.onOpenRelated(film);
            }
          }
        })
          .padding({ left: 12, right: 12, top: 4, bottom: 12 })
      }
    }
    .width('100%')
    .height('100%')
  }
}
