import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:collection/collection.dart';
import 'package:fuzzywuzzy/fuzzywuzzy.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:spotify/spotify.dart';
import 'package:spotube/collections/spotube_icons.dart';
import 'package:spotube/components/genre/category_card.dart';
import 'package:spotube/components/shared/expandable_search/expandable_search.dart';
import 'package:spotube/components/shared/shimmers/shimmer_categories.dart';
import 'package:spotube/components/shared/waypoint.dart';

import 'package:spotube/provider/user_preferences/user_preferences_provider.dart';
import 'package:spotube/services/queries/queries.dart';
import 'package:very_good_infinite_list/very_good_infinite_list.dart';

class GenrePage extends HookConsumerWidget {
  const GenrePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, ref) {
    final scrollController = useScrollController();
    final recommendationMarket = ref.watch(
      userPreferencesProvider.select((s) => s.recommendationMarket),
    );
    final categoriesQuery = useQueries.category.list(ref, recommendationMarket);
    final isFiltering = useState(false);

    final isMounted = useIsMounted();

    final searchController = useTextEditingController();
    final searchFocus = useFocusNode();

    useValueListenable(searchController);

    final categories = useMemoized(
      () {
        final categories = categoriesQuery.pages
            .expand<Category>(
              (page) => page.items ?? const Iterable.empty(),
            )
            .toList();
        if (searchController.text.isEmpty) {
          return categories;
        }
        return categories
            .map((e) => (
                  weightedRatio(e.name!, searchController.text),
                  e,
                ))
            .sorted((a, b) => b.$1.compareTo(a.$1))
            .where((e) => e.$1 > 50)
            .map((e) => e.$2)
            .toList();
      },
      [categoriesQuery.pages, searchController.text],
    );

    final list = RefreshIndicator(
      onRefresh: () async {
        await categoriesQuery.refreshAll();
      },
      child: Waypoint(
        onTouchEdge: () async {
          if (categoriesQuery.hasNextPage && isMounted()) {
            await categoriesQuery.fetchNext();
          }
        },
        controller: scrollController,
        child: Column(
          children: [
            ExpandableSearchField(
              isFiltering: isFiltering.value,
              onChangeFiltering: (value) => isFiltering.value = value,
              searchController: searchController,
              searchFocus: searchFocus,
            ),
            if (!categoriesQuery.hasPageData &&
                !categoriesQuery.isLoadingNextPage)
              const ShimmerCategories()
            else
              Expanded(
                child: InfiniteList(
                  scrollController: scrollController,
                  itemCount: categories.length,
                  onFetchData: categoriesQuery.fetchNext,
                  isLoading: categoriesQuery.isLoadingNextPage,
                  hasReachedMax: !categoriesQuery.hasNextPage,
                  loadingBuilder: (context) => const ShimmerCategories(),
                  itemBuilder: (context, index) {
                    return CategoryCard(categories[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );

    return Stack(
      children: [
        Positioned.fill(child: list),
        Positioned(
          top: 0,
          right: 10,
          child: ExpandableSearchButton(
            isFiltering: isFiltering.value,
            searchFocus: searchFocus,
            icon: const Icon(SpotubeIcons.search),
            onPressed: (value) {
              isFiltering.value = value;
              if (isFiltering.value) {
                scrollController.animateTo(
                  0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              }
            },
          ),
        ),
      ],
    );
  }
}
