import 'package:flutter/material.dart';
import 'package:flutter_settings_screen_ex/flutter_settings_screen_ex.dart';
import 'package:otzaria/screens/combined_book_screen.dart';
import '../model/books.dart';
import 'package:otzaria/screens/text_book_search_screen.dart';
import 'dart:io';
import 'package:otzaria/screens/toc_navigator_screen.dart';
import 'dart:math';
import 'links_screen.dart';
import 'commentators_list_screen.dart';
import 'package:flutter/services.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:otzaria/widgets/commentary_list.dart';
import 'package:otzaria/model/tabs.dart';
import 'package:otzaria/utils/text_manipulation.dart' as utils;

/// A [StatefulWidget] that displays a text book.
///
/// This widget takes a [TextBookTab] that contains the details of the book
/// and the data to display, and a [Future<String>] that represents the
/// contents of the book. It also takes two callbacks: [openBookCallback]
/// which is called when the user wants to open another book, and
/// [addBookmarkCallback] which is called when the user wants to add a bookmark.
///
/// [TextBookViewer] is responsible for displaying the book's contents and
/// allowing the user to interact with it, such as adjusting the font size
/// and searching for text within the book.
class TextBookViewer extends StatefulWidget {
  final TextBookTab tab;
  final void Function(OpenedTab) openBookCallback;
  final void Function(
      {required String ref,
      required String title,
      required int index}) addBookmarkCallback;
  final Future<String> data;

  /// Creates a new [TextBookViewer].
  ///
  /// The [tab] parameter is the [TextBookTab] that contains the details of the
  /// book, the [openBookCallback] parameter is the callback that is called
  /// when the user wants to open another book, and the [addBookmarkCallback]
  /// parameter is the callback that is called when the user wants to add a bookmark.
  /// The [data] parameter is the [Future<String>] that represents the contents
  /// of the book.
  const TextBookViewer({
    Key? key,
    required this.tab,
    required this.openBookCallback,
    required this.addBookmarkCallback,
    required this.data,
  }) : super(key: key);

  /// Creates the mutable state for this widget at a given location in the tree.
  @override
  State<TextBookViewer> createState() => _TextBookViewerState();
}

class _TextBookViewerState extends State<TextBookViewer>
    with
        AutomaticKeepAliveClientMixin<TextBookViewer>,
        TickerProviderStateMixin {
  double textFontSize = Settings.getValue('key-font-size') ?? 25.0;
  final showLeftPane = ValueNotifier<bool>(false);
  final pinLeftPane = ValueNotifier<bool>(false);
  final FocusNode textSearchFocusNode = FocusNode();
  final ValueNotifier<bool> showSplitedView = ValueNotifier<bool>(true);
  late TabController tabController;

  @override
  initState() {
    super.initState();
    tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
        appBar: buildAppBar(),
        body: Row(children: [
          buildTabBar(),
          buildHTMLViewer(),
        ]));
  }

  Widget buildHTMLViewer() {
    return Expanded(
      child: FutureBuilder(
          future: widget.data,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }

              if (snapshot.hasData) {
                return ValueListenableBuilder(
                    valueListenable: widget.tab.searchTextController,
                    builder: (context, searchTextController, child) => Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 5, 5),
                        child: NotificationListener<UserScrollNotification>(
                            onNotification: (scrollNotification) {
                              //unless links is shown, close left pane on scrolling
                              if (!pinLeftPane.value) {
                                Future.microtask(() {
                                  showLeftPane.value = false;
                                });
                              }

                              return false; // Don't block the notification
                            },
                            child: CallbackShortcuts(
                                bindings: <ShortcutActivator, VoidCallback>{
                                  LogicalKeySet(LogicalKeyboardKey.control,
                                      LogicalKeyboardKey.keyF): () {
                                    showLeftPane.value = true;
                                    tabController.index = 1;
                                  },
                                },
                                child: Focus(
                                    focusNode: FocusNode(),
                                    //don't autofocus on android, so that the keyboard doesn't appear
                                    autofocus:
                                        Platform.isAndroid ? false : true,
                                    child: ValueListenableBuilder(
                                      valueListenable: showSplitedView,
                                      builder: (context, value, child) =>
                                          ValueListenableBuilder(
                                              valueListenable:
                                                  widget.tab.commentariesToShow,
                                              builder: (context, value, child) {
                                                if (showSplitedView.value &&
                                                    widget
                                                        .tab
                                                        .commentariesToShow
                                                        .value
                                                        .isNotEmpty) {
                                                  return buildSplitedView(
                                                      snapshot,
                                                      searchTextController);
                                                } else {
                                                  return buildCombinedView(
                                                      snapshot,
                                                      searchTextController);
                                                }
                                              }),
                                    ))))));
              }
            }
            return const Center(child: CircularProgressIndicator());
          }),
    );
  }

  Widget buildSplitedView(
      AsyncSnapshot<String> snapshot, TextEditingValue searchTextController) {
    return ValueListenableBuilder(
        valueListenable: widget.tab.commentariesToShow,
        builder: (context, commentariesNames, child) => MultiSplitView(
                axis: Axis.horizontal,
                resizable: true,
                dividerBuilder: (axis, index, resizable, dragging, highlighted,
                        themeData) =>
                    const VerticalDivider(),
                children: [
                  SelectionArea(
                    child: CommentaryList(
                      index: widget
                              .tab.positionsListener.itemPositions.value.isEmpty
                          ? 0
                          : widget.tab.positionsListener.itemPositions.value
                              .first.index,
                      textBookTab: widget.tab,
                      fontSize: textFontSize,
                      openBookCallback: widget.openBookCallback,
                      showSplitView: showSplitedView,
                    ),
                  ),
                  buildCombinedView(snapshot, searchTextController)
                ]));
  }

  Widget buildCombinedView(
      AsyncSnapshot<String> snapshot, TextEditingValue searchTextController) {
    return CombinedView(
      key: PageStorageKey(widget.tab),
      tab: widget.tab,
      data: snapshot.data!.split('\n'),
      textSize: textFontSize,
      openBookCallback: widget.openBookCallback,
      showSplitedView: showSplitedView,
    );
  }

  AnimatedSize buildTabBar() {
    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      child: ValueListenableBuilder(
        valueListenable: showLeftPane,
        builder: (context, showLeftPane, child) => SizedBox(
          width: showLeftPane ? 400 : 0,
          child: child!,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(1, 0, 4, 0),
          child: Column(children: [
            Row(
              children: [
                Expanded(
                  child: TabBar(
                    tabs: const [
                      Tab(text: 'ניווט'),
                      Tab(text: 'חיפוש'),
                      Tab(text: 'פרשנות'),
                      Tab(text: 'קישורים')
                    ],
                    controller: tabController,
                    onTap: (value) {
                      if (value == 1 && !Platform.isAndroid) {
                        textSearchFocusNode.requestFocus();
                      }
                    },
                  ),
                ),
                ValueListenableBuilder(
                  valueListenable: pinLeftPane,
                  builder: (context, pinLeftPanel, child) => IconButton(
                    onPressed: () {
                      pinLeftPane.value = !pinLeftPane.value;
                    },
                    icon: const Icon(
                      Icons.push_pin,
                    ),
                    isSelected: pinLeftPanel,
                  ),
                )
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: tabController,
                children: [
                  buildTocViewer(),
                  buildSearchView(),
                  buildCommentaryView(),
                  buildLinkView(),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }

  FutureBuilder<String> buildSearchView() {
    return FutureBuilder(
        future: widget.data,
        builder: (context, snapshot) =>
            snapshot.connectionState == ConnectionState.done
                ? TextBookSearchView(
                    focusNode: textSearchFocusNode,
                    data: snapshot.data!,
                    scrollControler: widget.tab.scrollController,
                    searchTextController: widget.tab.searchTextController,
                    closeLeftPaneCallback: closeLeftPane,
                  )
                : const Center(child: CircularProgressIndicator()));
  }

  Widget buildTocViewer() {
    return TocViewer(
      toc: widget.tab.toc,
      scrollController: widget.tab.scrollController,
      closeLeftPaneCallback: closeLeftPane,
    );
  }

  LinksViewer buildLinkView() {
    return LinksViewer(
      links: widget.tab.links,
      openTabcallback: widget.openBookCallback,
      itemPositionsListener: widget.tab.positionsListener,
      closeLeftPanelCallback: closeLeftPane,
    );
  }

  CommentaryListView buildCommentaryView() {
    return CommentaryListView(
      tab: widget.tab,
    );
  }

  AppBar buildAppBar() {
    return AppBar(
      title: ListenableBuilder(
          listenable: widget.tab.positionsListener.itemPositions,
          builder: (context, _) {
            return FutureBuilder(
              future: refFromIndex(widget
                      .tab.positionsListener.itemPositions.value.isNotEmpty
                  ? widget.tab.positionsListener.itemPositions.value.first.index
                  : 0),
              builder: (context, snapshot) => snapshot.hasData
                  ? Text(snapshot.data!)
                  : const SizedBox.shrink(),
            );
          }),
      leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: "ניווט וחיפוש",
          onPressed: () {
            showLeftPane.value = !showLeftPane.value;
          }),
      actions: [
        // button to switch between splitted view and combined view
        ValueListenableBuilder(
          valueListenable: showSplitedView,
          builder: (context, showSplitedViewValue, child) => IconButton(
            onPressed: () {
              showSplitedView.value = !showSplitedView.value;
            },
            icon: Icon(!showSplitedView.value
                ? Icons.vertical_split_outlined
                : Icons.horizontal_split_outlined),
            tooltip: !showSplitedView.value
                ? ' הצגת מפרשים בצד הטקסט'
                : 'הצגת מפרשים מתחת הטקסט',
          ),
        ),

        //button to add a bookmark
        IconButton(
          onPressed: () async {
            int index =
                widget.tab.positionsListener.itemPositions.value.first.index;
            widget.addBookmarkCallback(
                ref: widget.tab.title + await refFromIndex(index),
                title: utils.getTitleFromPath(widget.tab.book.title),
                index: index);
          },
          icon: const Icon(
            Icons.bookmark_add,
          ),
          tooltip: 'הוספת סימניה',
        ),

        // button to search
        IconButton(
          onPressed: () {
            showLeftPane.value = true;
            tabController.index = 1;
            textSearchFocusNode.requestFocus();
          },
          icon: const Icon(
            Icons.search,
          ),
          tooltip: 'חיפוש',
        ),

        // button to zoom in
        IconButton(
            icon: const Icon(
              Icons.zoom_in,
            ),
            tooltip: 'הגדלת טקסט',
            onPressed: () => setState(() {
                  textFontSize = min(50.0, textFontSize + 3);
                })),
        IconButton(
          icon: const Icon(
            Icons.zoom_out,
          ),
          tooltip: 'הקטנת טקסט',
          onPressed: () => setState(() {
            textFontSize = max(15.0, textFontSize - 3);
          }),
        ),
        // button to scroll all the way up
        IconButton(
            icon: const Icon(Icons.first_page),
            tooltip: 'תחילת הספר',
            onPressed: () {
              widget.tab.scrollController.scrollTo(
                  index: 0, duration: const Duration(milliseconds: 300));
            }),
        //button to scroll to previous section
        IconButton(
            icon: const Icon(Icons.navigate_before),
            tooltip: 'הקטע הקודם',
            onPressed: () {
              widget.tab.scrollController.scrollTo(
                  duration: const Duration(milliseconds: 300),
                  index: max(
                    0,
                    widget.tab.positionsListener.itemPositions.value.first
                            .index -
                        1,
                  ));
            }),
        //button to scroll to next section
        IconButton(
            icon: const Icon(Icons.navigate_next),
            tooltip: 'הקטע הבא',
            onPressed: () {
              widget.tab.scrollController.scrollTo(
                  index: max(
                      widget.tab.positionsListener.itemPositions.value.first
                              .index +
                          1,
                      widget.tab.positionsListener.itemPositions.value.length -
                          1),
                  duration: const Duration(milliseconds: 300));
            }),

        // button to scroll all the way down
        IconButton(
            icon: const Icon(Icons.last_page),
            tooltip: 'סוף הספר',
            onPressed: () async {
              widget.tab.scrollController.scrollTo(
                  index: await widget.data.then((value) => value.length),
                  duration: const Duration(milliseconds: 300));
            }),
      ],
    );
  }

  void closeLeftPane() {
    showLeftPane.value = false;
  }

  Future<String> refFromIndex(int index) async {
    List<TocEntry> toc = await widget.tab.toc;
    List<String> texts = [];

    void searchToc(List<TocEntry> entries, int index) {
      for (final TocEntry entry in entries) {
        if (entry.index > index) {
          return;
        }
        if (entry.level > texts.length) {
          texts.add(entry.text);
        } else {
          texts[entry.level - 1] = entry.text;
        }

        searchToc(entry.children, index);
      }
    }

    searchToc(toc, index);

    return texts.join(',');
  }

  @override
  bool get wantKeepAlive => true;
}
