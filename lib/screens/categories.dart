import "package:flutter/material.dart";
import "package:kisekae/core/notifications/theme/app_theme.dart";
import "package:kisekae/screens/products_list.dart";
import "package:kisekae/screens/subcategories/kids.dart";
import "package:kisekae/screens/subcategories/mens.dart";
import "package:kisekae/screens/subcategories/womens.dart";
import "package:kisekae/widgets/bottom_bar.dart";
import "package:kisekae/widgets/searchbar.dart";

class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  static const _categories = <(String, String, Alignment)>[
    ("Women's Fashion", "assets/images/category1.png", Alignment(0, -0.5)),
    ("Men's Fashion", "assets/images/category2.png", Alignment(0, -0.5)),
    ("Kids Wear", "assets/images/category3.png", Alignment(0, -0.5)),
    ("Ethnic Wear", "assets/images/category4.png", Alignment.center),
    ("Formals", "assets/images/category5.png", Alignment(0, -0.5)),
    ("Sports Wear", "assets/images/category6.png", Alignment.topCenter),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () {
            Navigator.pop(context);
          },
          icon: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
              border: Border.all(color: colors.onSurface, width: 2),
            ),
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: colors.onSurface,
            ),
          ),
        ),
        centerTitle: true,
        title: const Text(
          "Categories",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(58),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: KisekaeSearchBar(),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              Column(
                spacing: 16,
                children: [
                  for (var i = 0; i < _categories.length; i++)
                    _categoryCard(
                      context,
                      _categories[i].$1,
                      _categories[i].$2,
                      _categories[i].$3,
                      () {
                        late final Widget screen;
                        switch (i) {
                          case 0:
                            screen = WomensSubCategoriesScreen();
                            break;
                          case 1:
                            screen = MensSubCategoriesScreen();
                            break;
                          case 2:
                            screen = KidsSubCategoriesScreen();
                            break;
                          case 3:
                            screen = ProductListScreen(initialQuery: "Ethinic");
                            break;
                          case 4:
                            screen = ProductListScreen(initialQuery: "Formals");
                            break;
                          case 5:
                            screen = ProductListScreen(initialQuery: "Sports");
                            break;
                        }
                        Navigator.of(context)
                            .push(MaterialPageRoute(builder: (_) => screen));
                      },
                      imageOnLeft: i.isOdd,
                    ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
      bottomNavigationBar: const BottomBar(selectedIndex: 1),
    );
  }

  Widget _categoryCard(
    BuildContext context,
    String label,
    String imageUrl,
    Alignment alignment,
    VoidCallback onTap, {
    required bool imageOnLeft,
  }) {
    final cardColor = context.appColors.card;
    final isDark = Theme.of(context).colorScheme.brightness == Brightness.dark;

    final image = SizedBox(
      width: 110,
      height: double.infinity,
      child: Image.asset(
        imageUrl,
        fit: BoxFit.cover,
        alignment: alignment,
        // light: same card-colored tint as before; dark: no tint
        color: isDark ? null : cardColor,
        colorBlendMode: BlendMode.multiply,
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 96,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            if (imageOnLeft) image,
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  label,
                  textAlign: imageOnLeft ? TextAlign.right : TextAlign.left,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            if (!imageOnLeft) image,
          ],
        ),
      ),
    );
  }
}
