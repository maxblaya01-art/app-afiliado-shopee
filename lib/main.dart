import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const ShopeeAffiliateApp());
}

class ShopeeAffiliateApp extends StatelessWidget {
  const ShopeeAffiliateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Divulgador Shopee',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController linkController = TextEditingController();

  String produto = '';
  String preco = '';
  String imagem = '';

  bool carregando = false;

  Future<void> buscarProduto() async {
    final link = linkController.text.trim();

    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cole primeiro o link do produto da Shopee.'),
        ),
      );
      return;
    }

    setState(() {
      carregando = true;
    });

    // Nesta primeira versão vamos preparar a tela.
    // A integração real com a API da Shopee será adicionada depois.

    await Future.delayed(const Duration(seconds: 1));

    setState(() {
      carregando = false;
      produto = 'Produto da Shopee';
      preco = 'Preço será carregado pela API';
      imagem = '';
    });
  }

  Future<void> abrirLink() async {
    final link = linkController.text.trim();

    if (link.isEmpty) return;

    final uri = Uri.tryParse(link);

    if (uri != null) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Divulgador Shopee'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),

            const Icon(
              Icons.shopping_bag,
              size: 70,
              color: Colors.deepOrange,
            ),

            const SizedBox(height: 15),

            const Text(
              'Divulgue seus produtos',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Cole o link do produto da Shopee abaixo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),

            const SizedBox(height: 25),

            TextField(
              controller: linkController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link do produto',
                hintText: 'https://shopee.com.br/...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: carregando ? null : buscarProduto,
              icon: carregando
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(
                carregando
                    ? 'Buscando...'
                    : 'Buscar produto',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

            const SizedBox(height: 25),

            if (produto.isNotEmpty)
              Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (imagem.isNotEmpty)
                        Image.network(
                          imagem,
                          height: 220,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) {
                            return const Icon(
                              Icons.image_not_supported,
                              size: 100,
                            );
                          },
                        ),

                      const SizedBox(height: 15),

                      Text(
                        produto,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        preco,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),

                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: abrirLink,
                        icon: const Icon(Icons.open_in_new),
                        label: const Text(
                          'Abrir link do produto',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    linkController.dispose();
    super.dispose();
  }
}
