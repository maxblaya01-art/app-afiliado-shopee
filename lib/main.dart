import 'package:flutter/material.dart';

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
  String linkFinal = '';

  bool carregando = false;

  void buscarProduto() {
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
      linkFinal = link;
    });

    // Nesta primeira etapa usamos dados de demonstração.
    // Depois vamos conectar a busca real do produto.

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      setState(() {
        carregando = false;
        produto = 'Produto Shopee';
        preco = 'Preço será carregado automaticamente';
        imagem = '';
      });
    });
  }

  void copiarDivulgacao() {
    if (produto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Busque um produto primeiro.'),
        ),
      );
      return;
    }

    final texto = '''
🛍️ $produto

💰 $preco

🔥 Aproveite essa oferta!

👉 Compre aqui:
$linkFinal
''';

    // Nesta etapa apenas mostramos a divulgação.
    // O botão de copiar será conectado na próxima etapa.

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Divulgação'),
          content: SingleChildScrollView(
            child: SelectableText(texto),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    linkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Divulgador Shopee'),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
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
              'Divulgador Shopee',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Cole o link do produto para gerar sua divulgação.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 25),

            TextField(
              controller: linkController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link do produto Shopee',
                hintText: 'https://shopee.com.br/...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: carregando ? null : buscarProduto,
                icon: carregando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  carregando ? 'Buscando...' : 'BUSCAR PRODUTO',
                ),
              ),
            ),

            const SizedBox(height: 30),

            if (produto.isNotEmpty)
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: imagem.isEmpty
                            ? const Icon(
                                Icons.image,
                                size: 70,
                                color: Colors.grey,
                              )
                            : Image.network(
                                imagem,
                                fit: BoxFit.contain,
                              ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'PRODUTO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        produto,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 15),

                      const Text(
                        'PREÇO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        preco,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'LINK DE DIVULGAÇÃO',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 5),

                      SelectableText(
                        linkFinal,
                        style: const TextStyle(
                          color: Colors.blue,
                        ),
                      ),

                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: copiarDivulgacao,
                        icon: const Icon(Icons.copy),
                        label: const Text(
                          'GERAR DIVULGAÇÃO',
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
}
