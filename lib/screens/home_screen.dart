import 'package:flutter/material.dart';
import 'package:kisekae/screens/getting_started.dart';
import 'package:kisekae/screens/products_list.dart';
import 'package:kisekae/screens/search.dart';
import 'package:kisekae/services/email_auth.dart';
import 'package:kisekae/widgets/bottom_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoggingOut = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: const Text(
                "KISEKAE",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF7D2938),
                  fontFamily: 'serif',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.place_rounded),
                const Text("HOME", style: TextStyle(fontSize: 18)),
                Icon(Icons.keyboard_arrow_down),
              ],
            ),
          ],
        ),
        // actions: [
        //   TextButton.icon(
        //     onPressed: _logout,
        //     icon: Icon(Icons.logout),
        //     label: const Text("Logout"),
        //   ),
        // ],
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SearchScreen()),
                    );
                  },
                  label: const Text(
                    'EXPLORE YOUR STYLE',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.5,
                    ),
                  ),
                  icon: Icon(Icons.search, size: 24, color: Colors.black),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE8D8C4),
                    alignment: Alignment.centerLeft,
                    padding: EdgeInsets.symmetric(vertical: 10, horizontal: 16),
                    side: BorderSide(color: const Color(0xFFB78876)),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Image.asset(
                  'assets/images/homescreen.png',
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Categories',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProductsListScreen()),
                      );
                    },
                    icon: Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _CategoryImage(
                    imageUrl: 'assets/images/clothes/4.jpg',
                    alignment: Alignment.topCenter,
                    label: 'Women',
                  ),
                  _CategoryImage(
                    imageUrl: 'assets/images/clothes/7.jpg',
                    alignment: Alignment.topCenter,
                    label: 'Men',
                  ),
                  _CategoryImage(
                    imageUrl: 'assets/images/clothes/5.jpg',
                    alignment: Alignment.topCenter,
                    label: 'Kids',
                  ),
                  _CategoryImage(
                    imageUrl: 'assets/images/clothes/6.jpg',
                    alignment: Alignment(0, -0.5),
                    label: 'Formals',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Continue Shopping For',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ProductsListScreen()),
                      );
                    },
                    icon: Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ProductCard(
                      imageUrl: 'assets/images/clothes/8.jpg',
                      title: 'floral top',
                      rating: 3.9,
                      price: 375,
                      alignment: Alignment(0, -0.4),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ProductCard(
                      imageUrl: 'assets/images/clothes/6.jpg',
                      title: 'tailored blazer',
                      rating: 4.5,
                      price: 705,
                      alignment: Alignment(0, -0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Best Deals',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProductsListScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.arrow_forward),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: ProductCard(
                      imageUrl: 'assets/images/clothes/7.jpg',
                      title: 'tailored blazer',
                      rating: 4.5,
                      price: 705,
                      alignment: Alignment(0, -0.75),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ProductCard(
                      imageUrl: 'assets/images/clothes/9.jpg',
                      title: 'tailored blazer',
                      rating: 4.5,
                      price: 705,
                      alignment: Alignment(0, -0.75),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: BottomBar(),
    );
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      final response = await EmailAuth().logout();
      if (!mounted) return;
      if (response.success) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const GettingStartedScreen()),
          (route) => false,
        );
      }
      if (response.message.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: response.success ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }
}

class ProductCard extends StatelessWidget {
  final String imageUrl;
  final String title;
  final double rating;
  final int price;
  final Alignment alignment;

  const ProductCard({
    super.key,
    required this.imageUrl,
    required this.title,
    required this.rating,
    required this.price,
    required this.alignment,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Color(0xFF8B2E3E)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16.5),
              child: Image.asset(
                imageUrl,
                fit: BoxFit.cover,
                alignment: alignment,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 4),
              const Icon(Icons.star, size: 16, color: Colors.amber),
              Text('$rating'),
            ],
          ),
          Text(
            '₹$price',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _CategoryImage extends StatelessWidget {
  final String imageUrl;
  final Alignment alignment;
  final String label;
  const _CategoryImage({
    required this.imageUrl,
    required this.alignment,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          CircleAvatar(
            radius: 27,
            backgroundColor: const Color(0xFFDBBEC3),
            child: ClipOval(
              child: Image.asset(
                imageUrl,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                alignment: alignment,
              ),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}
