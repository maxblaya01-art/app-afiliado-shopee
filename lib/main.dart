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
  String erro = '';

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
      final uri = Uri.parse(link);

      final resposta = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
          'Accept-Language': 'pt-BR,pt;q=0.9,en-US;q=0.8,en;q=0.7',
        },
      );

      if (resposta.statusCode < 200 || resposta.statusCode >= 400) {
        throw Exception(
          'A Shopee respondeu com o código ${resposta.statusCode}.',
        );
      }

      final html = utf8.decode(resposta.bodyBytes);

      String titulo = extrairMeta(html, 'og:title');

      if (titulo.isEmpty) {
        titulo = extrairJson(html, 'name');
      }

      String img = extrairMeta(html, 'og:image');

      if (img.isEmpty) {
        img = extrairJson(html, 'image');
      }

      String valor = extrairMeta(html, 'product:price:amount');

      if (valor.isEmpty) {
        valor = procurarPreco(html);
      }

      String urlFinal = extrairCanonical(html);

      if (urlFinal.isEmpty) {
        urlFinal = resposta.request?.url.toString() ?? link;
      }

      titulo = limparTexto(titulo);
      img = limparTexto(img);
      valor = limparTexto(valor);

      if (titulo.isEmpty) {
        titulo = 'Produto Shopee';
      }

      if (valor.isEmpty) {
        valor = 'Preço não encontrado';
      }

      setState(() {
        produto = titulo;
        preco = formatarPreco(valor);
        imagem = img;
        linkFinal = urlFinal;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        carregando = false;
        erro =
            'Não foi possível carregar o produto.\n\n'
            'A Shopee pode ter bloqueado a consulta desse link. '
            'Tente usar o link completo do produto.';
      });
    }
  }

  String extrairMeta(String html, String propriedade) {
    final padroes = [
      RegExp(
        '<meta[^>]+property=["\']$propriedade["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+content=["\']([^"\']+)["\'][^>]+property=["\']$propriedade["\']',
        caseSensitive: false,
      ),
      RegExp(
        '<meta[^>]+name=["\']$propriedade["\'][^>]+content=["\']([^"\']+)["\']',
        caseSensitive: false,
      ),
    ];

    for (final padrao in padroes) {
      final resultado = padrao.firstMatch(html);

      if (resultado != null) {
        return resultado.group(1) ?? '';
      }
    }

    return '';
  }

  String extrairJson(String html, String chave) {
    final padrao = RegExp(
      '"$chave"\\s*:\\s*"([^"]+)"',
      caseSensitive: false,
    );

    final resultado = padrao.firstMatch(html);

    return resultado?.group(1) ?? '';
  }

  String procurarPreco(String html) {
    final padroes = [
      RegExp(r'R\$\s?[0-9]{1,3}(?:\.[0-9]{3})*,[0-9]{2}'),
      RegExp(r'"price"\s*:\s*"([^"]+)"'),
      RegExp(r'"price"\s*:\s*([0-9.]+)'),
    ];

    for (final padrao in padroes) {
      final resultado = padrao.firstMatch(html);

      if (resultado != null) {
        return resultado.group(1) ?? resultado.group(0) ?? '';
      }
    }

    return '';
  }

  String extrairCanonical(String html) {
    final padrao = RegExp(
      '<link[^>]+rel=["\']canonical["\'][^>]+href=["\']([^"\']+)["\']',
      caseSensitive: false,
    );

    final resultado = padrao.firstMatch(html);

    return resultado?.group(1) ?? '';
  }

  String limparTexto(String texto) {
    return texto
        .replaceAll(r'\/', '/')
        .replaceAll(r'\"', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }

  String formatarPreco(String valor) {
    if (valor.isEmpty || valor == 'Preço não encontrado') {
      return valor;
    }

    if (valor.startsWith('R\$')) {
      return valor;
    }

    final numero = double.tryParse(valor.replaceAll(',', '.'));

    if (numero != null) {
      return 'R\$ ${numero.toStringAsFixed(2).replaceAll('.', ',')}';
    }

    return valor;
  }

  void limpar() {
    linkController.clear();

    setState(() {
      produto = '';
      preco = '';
      imagem = '';
      linkFinal = '';
      erro = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F5),
      appBar: AppBar(
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
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
              'Cole o link do produto para buscar as informações.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                color: Colors.brown,
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
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: limpar,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed: carregando ? null : buscarProduto,
              icon: carregando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.search),
              label: Text(
                carregando ? 'CARREGANDO...' : 'BUSCAR PRODUTO',
                style: const TextStyle(fontSize: 17),
              ),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 58),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),

            const SizedBox(height: 25),

            if (erro.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.red.shade200,
                  ),
                ),
                child: Text(
                  erro,
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 16,
                  ),
                ),
              ),

            if (produto.isNotEmpty)
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (imagem.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.network(
                            imagem,
                            height: 260,
                            fit: BoxFit.contain,
                            errorBuilder: (
                              context,
                              error,
                              stackTrace,
                            ) {
                              return Container(
                                height: 260,
                                color: Colors.grey.shade200,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  size: 70,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                        )
                      else
                        Container(
                          height: 260,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.image,
                            size: 80,
                            color: Colors.grey,
                          ),
                        ),

                      const SizedBox(height: 20),

                      const Text(
                        'PRODUTO',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        produto,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'PREÇO',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        preco,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.bold,
                          color: Colors.deepOrange,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        'LINK DE DIVULGAÇÃO',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),

                      const SizedBox(height: 5),

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

                      ElevatedButton.icon(
                        onPressed: () {
                          final texto =
                              '🔥 OFERTA SHOPEE 🔥\n\n'
                              '$produto\n\n'
                              '💰 $preco\n\n'
                              '🛒 Compre aqui:\n'
                              '${linkFinal.isEmpty ? linkController.text : linkFinal}';

                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                texto,
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.copy),
                        label: const Text(
                          'GERAR DIVULGAÇÃO',
                          style: TextStyle(fontSize: 17),
                        ),
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 55),
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
