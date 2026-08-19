import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const DivulgadorShopeeApp());
}

class DivulgadorShopeeApp extends StatelessWidget {
  const DivulgadorShopeeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Divulgador Shopee',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepOrange,
        ),
        scaffoldBackgroundColor: const Color(0xFFFFF8F5),
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
  String erro = '';

  bool carregando = false;

  Future<void> buscarProduto() async {
    final link = linkController.text.trim();

    if (link.isEmpty) {
      setState(() {
        erro = 'Cole o link do produto da Shopee.';
      });
      return;
    }

    if (!link.contains('shopee')) {
      setState(() {
        erro = 'Esse link não parece ser um link da Shopee.';
      });
      return;
    }

    setState(() {
      carregando = true;
      erro = '';
      produto = '';
      preco = '';
      imagem = '';
      linkFinal = '';
    });

    try {
      Uri uri = Uri.parse(link);

      final client = http.Client();

      try {
        final resposta = await client.get(
          uri,
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/126.0 Mobile Safari/537.36',
            'Accept':
                'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
          },
        );

        final html = utf8.decode(resposta.bodyBytes);

        final titulo = _pegarMeta(html, 'og:title');
        final imagemEncontrada = _pegarMeta(html, 'og:image');
        final descricao = _pegarMeta(html, 'og:description');

        String nomeProduto = titulo;

        if (nomeProduto.isEmpty) {
          nomeProduto = _pegarTitle(html);
        }

        String precoEncontrado = _encontrarPreco(html);

        if (precoEncontrado.isEmpty && descricao.isNotEmpty) {
          precoEncontrado = _encontrarPreco(descricao);
        }

        String urlFinal = resposta.request?.url.toString() ?? link;

        if (resposta.statusCode >= 200 && resposta.statusCode < 400) {
          setState(() {
            produto = nomeProduto.isNotEmpty
                ? _limparTexto(nomeProduto)
                : 'Produto Shopee';

            preco = precoEncontrado.isNotEmpty
                ? precoEncontrado
                : 'Preço não encontrado';

            imagem = imagemEncontrada;
            linkFinal = urlFinal;
            carregando = false;

            if (nomeProduto.isEmpty &&
                precoEncontrado.isEmpty &&
                imagemEncontrada.isEmpty) {
              erro =
                  'A Shopee não liberou os dados do produto para este acesso.';
            }
          });
        } else {
          setState(() {
            carregando = false;
            erro =
                'A Shopee respondeu com erro ${resposta.statusCode}. '
                'Tente abrir o link no navegador primeiro.';
          });
        }
      } finally {
        client.close();
      }
    } catch (e) {
      setState(() {
        carregando = false;
        erro =
            'Não foi possível carregar o produto. '
            'Verifique sua internet e tente novamente.';
      });
    }
  }

  String _pegarMeta(String html, String propriedade) {
    final padroes = [
      RegExp(
        '<meta[^>]+property=["\']$propriedade["\'][^>]+content=["\']([^"\']*)',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']*)["\'][^>]+property=["\']$propriedade["\']',
        caseSensitive: false,
      ),
    ];

    for (final regex in padroes) {
      final resultado = regex.firstMatch(html);

      if (resultado != null) {
        return _decodificarHtml(resultado.group(1) ?? '');
      }
    }

    return '';
  }

  String _pegarTitle(String html) {
    final resultado = RegExp(
      r'<title[^>]*>(.*?)</title>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);

    if (resultado != null) {
      return _decodificarHtml(resultado.group(1) ?? '');
    }

    return '';
  }

  String _encontrarPreco(String texto) {
    final padroes = [
      RegExp(r'R\$\s?\d{1,3}(?:\.\d{3})*,\d{2}'),
      RegExp(r'BRL\s?\d{1,3}(?:\.\d{3})*,\d{2}'),
      RegExp(r'"\$price"\s*:\s*"([^"]+)"'),
      RegExp(r'"price"\s*:\s*"([^"]+)"'),
    ];

    for (final regex in padroes) {
      final resultado = regex.firstMatch(texto);

      if (resultado != null) {
        return resultado.group(0) ?? '';
      }
    }

    return '';
  }

  String _decodificarHtml(String texto) {
    return texto
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  String _limparTexto(String texto) {
    return texto
        .replaceAll(' | Shopee Brasil', '')
        .replaceAll(' - Shopee', '')
        .trim();
  }

  void gerarDivulgacao() {
    if (linkFinal.isEmpty && linkController.text.trim().isEmpty) {
      return;
    }

    final link = linkFinal.isNotEmpty
        ? linkFinal
        : linkController.text.trim();

    final texto = '''
🔥 OFERTA NA SHOPEE 🔥

🛍️ $produto

💰 ${preco.isNotEmpty ? preco : 'Confira o preço'}

👉 COMPRE AQUI:
$link

⚡ Aproveite enquanto está disponível!
''';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Divulgação pronta'),
          content: SingleChildScrollView(
            child: SelectableText(texto),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('FECHAR'),
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
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.deepOrange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),

            const Text(
              'Cole o link de um produto da Shopee para buscar as informações automaticamente.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),

            const SizedBox(height: 25),

            TextField(
              controller: linkController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link do produto Shopee',
                hintText: 'https://s.shopee.com.br/...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),

            const SizedBox(height: 15),

            SizedBox(
              height: 55,
              child: ElevatedButton.icon(
                onPressed: carregando ? null : buscarProduto,
                icon: carregando
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.deepOrange,
                        ),
                      )
                    : const Icon(Icons.search),
                label: Text(
                  carregando ? 'CARREGANDO...' : 'BUSCAR PRODUTO',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            if (erro.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  erro,
                  style: const TextStyle(
                    color: Colors.deepOrange,
                    fontSize: 15,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 25),

            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imagem.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.network(
                          imagem,
                          width: double.infinity,
                          height: 230,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              height: 230,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                              ),
                            );
                          },
                        ),
                      )
                    else
                      Container(
                        width: double.infinity,
                        height: 230,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.image,
                            size: 65,
                            color: Colors.grey,
                          ),
                        ),
                      ),

                    const SizedBox(height: 20),

                    const Text(
                      'PRODUTO',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      produto.isEmpty ? 'Produto Shopee' : produto,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'PREÇO',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      preco.isEmpty
                          ? 'Preço será carregado automaticamente'
                          : preco,
                      style: const TextStyle(
                        fontSize: 22,
                        color: Colors.deepOrange,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'LINK DE DIVULGAÇÃO',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 6),

                    SelectableText(
                      linkFinal.isEmpty
                          ? linkController.text
                          : linkFinal,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Colors.blue,
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: produto.isEmpty
                            ? null
                            : gerarDivulgacao,
                        icon: const Icon(Icons.copy),
                        label: const Text(
                          'GERAR DIVULGAÇÃO',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
