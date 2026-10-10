import 'package:flutter/material.dart';

class ProductsListScreen extends StatelessWidget {
  const ProductsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: const Icon(Icons.arrow_back_ios_new, size: 18),
          ),
        ),
        centerTitle: true,
        title: Text(
          "Products List",
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {},
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _optionsChip('Filter', selected: true),
                _optionsChip('Sort by'),
                _optionsChip('Discount'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                childAspectRatio: 0.82,
                children: [
                  _productCard(
                    'Maroon top',
                    'assets/images/clothes/10.jpg',
                    Alignment.topCenter,
                    5.0,
                    271,
                  ),
                  _productCard(
                    'Green blazer',
                    'assets/images/clothes/6.jpg',
                    Alignment.topCenter,
                    5.0,
                    710,
                  ),
                  _productCard(
                    'White top',
                    'assets/images/clothes/1.jpg',
                    Alignment.topCenter,
                    5.0,
                    375,
                  ),
                  _productCard(
                    'Denim jacket',
                    'assets/images/clothes/2.jpg',
                    Alignment.topCenter,
                    5.0,
                    405,
                  ),
                  _productCard(
                    'White tshirt',
                    'assets/images/clothes/3.jpg',
                    Alignment.topCenter,
                    5.0,
                    350,
                  ),
                  _productCard(
                    'Blue tshirt',
                    'assets/images/clothes/4.jpg',
                    Alignment.topCenter,
                    5.0,
                    300,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _optionsChip(String label, {bool selected = false}) {
    return Chip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: selected ? Colors.white : Colors.black,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: selected
          ? const Color(0xFF8B2E3E)
          : const Color(0xFFFFF9F2),
      side: selected ? BorderSide.none : BorderSide(color: Color(0xFFB78876)),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    );
  }

  Widget _productCard(
    String title,
    String imageUrl,
    Alignment alignment,
    double rating,
    int price,
  ) {
    return SizedBox(
      width: 190,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 150,
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
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 16)),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: Colors.amber),
                  Text('$rating'),
                ],
              ),
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
