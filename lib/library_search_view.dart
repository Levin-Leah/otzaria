import 'package:flutter/material.dart';
import 'package:otzaria/main_window_view.dart';
import 'package:flutter_settings_screen_ex/flutter_settings_screen_ex.dart';
import 'package:search_highlight_text/search_highlight_text.dart';
import 'tree_view_selectable.dart';
import 'library_searcher.dart';

class TextFileSearchScreen extends StatefulWidget {
  final void Function(TabWindow) openBookCallback;
  final LibrarySearcher searcher;

  const TextFileSearchScreen({
    super.key,
    required this.openBookCallback,
    required this.searcher,
  });

  @override
  TextFileSearchScreenState createState() => TextFileSearchScreenState();
}

class TextFileSearchScreenState extends State<TextFileSearchScreen>
    with AutomaticKeepAliveClientMixin<TextFileSearchScreen> {
  final showLeftPane = ValueNotifier<bool>(true);

  TextField buildSearchField(bool isSearching) {
    return TextField(
      controller: widget.searcher.queryController,
      onSubmitted: (e) => widget.searcher.search(),
      decoration: buildSearchDecoration(isSearching),
    );
  }

  InputDecoration buildSearchDecoration(bool isSearching) {
    return InputDecoration(
      hintText: "הקלד את הטקסט והקש אנטר או לחץ על סמל החיפוש",
      suffixIcon: isSearching
          ? Row(
              children: [
                Expanded(child: Text(widget.searcher.queryController.text)),
                IconButton(
                  icon: const Icon(Icons.cancel),
                  onPressed: () {
                    setState(() {
                      widget.searcher.queryController.clear();
                      widget.searcher.searchResults.value = [];
                      widget.searcher.isSearching.value = false;
                      widget.searcher.bookIndex = 0;
                    });
                  },
                ),
                const Center(child: CircularProgressIndicator())
              ],
            )
          : IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                widget.searcher.search();
              },
            ),
    );
  }

  ValueListenableBuilder<bool> buildIsSearchingBuilder() {
    return ValueListenableBuilder(
      valueListenable: widget.searcher.isSearching,
      builder: (context, isSearching, child) {
        return Row(
          children: [
            Expanded(
              child: buildSearchField(isSearching),
            ),
          ],
        );
      },
    );
  }

  ValueListenableBuilder<List<BookTextSearchResult>>
      buildSearchResultsBuilder() {
    return ValueListenableBuilder<List<BookTextSearchResult>>(
      valueListenable: widget.searcher.searchResults,
      builder: (context, searchResults, child) =>
          buildSearchResultsContent(searchResults),
    );
  }

  Widget buildEmptySearchResultsContent() {
    return Expanded(
      child: Column(
        children: [
          const Text("רשימת הספרים לחיפוש:"),
          Expanded(
              child: FileTreeViewScreen(
            checkedItems: widget.searcher.booksToSearch,
          )),
        ],
      ),
    );
  }

  Widget buildSearchResultsContent(List<BookTextSearchResult> searchResults) {
    return searchResults.isEmpty && !widget.searcher.isSearching.value
        ? buildEmptySearchResultsContent()
        : Expanded(
            child: Column(
              children: [
                buildSearchProgressBar(searchResults),
                buildSearchProgressStatus(searchResults),
                buildSearchResults(searchResults),
              ],
            ),
          );
  }

  Widget buildSearchProgressBar(searchResults) {
    // show progress bar if search is in progress
    // max value is widget.searcher.booksToSearch.length
    // current value is widget.searcher.bookIndex
    return SizedBox(
        height: 3.0,
        child: LinearProgressIndicator(
          value: widget.searcher.isSearching.value &&
                  widget.searcher.booksToSearch.isNotEmpty
              ? widget.searcher.bookIndex / widget.searcher.booksToSearch.length
              : 0.0,
          //backgroundColor: Colors.grey,
          borderRadius: const BorderRadius.all(Radius.circular(10)),
        ));
  }

  Widget buildSearchProgressStatus(searchResults) {
    return widget.searcher.searchStarted != null &&
            widget.searcher.searchFinished != null &&
            widget.searcher.searchFinished!
                .isAfter(widget.searcher.searchStarted!)
        ? Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text(
                'נסרקו ${widget.searcher.bookIndex} מתוך ${widget.searcher.booksToSearch.length} ספרים.  נמצאו ${searchResults.length} תוצאות בתוך ${DateTimeRange(start: widget.searcher.searchStarted!, end: widget.searcher.searchFinished!).duration.inSeconds} שניות'),
          )
        : const SizedBox.shrink();
  }

  Widget buildSearchResults(searchResults) {
    return searchResults.isEmpty &&
            !widget.searcher.isSearching.value &&
            widget.searcher.bookIndex == widget.searcher.booksToSearch.length
        // return empty list if no search results
        ? const Expanded(
            child: Center(
              child: Text(
                "אין תוצאות חיפוש",
                style: TextStyle(
                  fontSize: 20.0,
                ),
              ),
            ),
          )
        // return list of search results if there are any
        : Expanded(
            child: buildSearchResultsList(searchResults),
          );
  }

  ListView buildSearchResultsList(List<BookTextSearchResult> searchResults) {
    return ListView.builder(
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final result = searchResults[index];
        return ListTile(
          title: Text(
            result.address,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: SearchHighlightText(
            result.snippet,
            searchText: result.query,
            style: TextStyle(
              fontFamily: Settings.getValue<String>('key-font-family'),
              color: Colors.black,
              fontSize: 20.0,
            ),
            textAlign: TextAlign.justify,
          ),
          onTap: () {
            widget.openBookCallback(
              BookTabWindow(result.path, result.index,
                  searchText: result.query),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            buildIsSearchingBuilder(),
            buildSearchResultsBuilder(),
          ],
        ),
      ),
    );
  }

  @override
  get wantKeepAlive => true;
}
