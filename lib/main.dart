import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

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

    String urlTexto = link;

    if (!urlTexto.startsWith('http://') &&
        !urlTexto.startsWith('https://')) {
      urlTexto = 'https://$urlTexto';
    }

    Uri? uri;

    try {
      uri = Uri.parse(urlTexto);
    } catch (_) {
      setState(() {
        erro = 'O link informado não é válido.';
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
      final resposta = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'pt-BR,pt;q=0.9,en;q=0.8',
        },
      ).timeout(const Duration(seconds: 20));

      if (resposta.statusCode < 200 || resposta.statusCode >= 400) {
        throw Exception(
          'A Shopee respondeu com código ${resposta.statusCode}.',
        );
      }

      final html = utf8.decode(resposta.bodyBytes);
      final document = parser.parse(html);

      String pegarMeta(String nome) {
        final elemento = document.querySelector(
          'meta[property="$nome"], meta[name="$nome"]',
        );

        return elemento?.attributes['content']?.trim() ?? '';
      }

      String titulo = pegarMeta('og:title');

      if (titulo.isEmpty) {
        titulo = pegarMeta('twitter:title');
      }

      if (titulo.isEmpty) {
        titulo = document.querySelector('title')?.text.trim() ?? '';
      }

      String foto = pegarMeta('og:image');

      if (foto.isEmpty) {
        foto = pegarMeta('twitter:image');
      }

      String descricao = pegarMeta('og:description');

      String precoEncontrado = '';

      final textos = <String>[
        titulo,
        descricao,
        document.body?.text ?? '',
      ];

      final textoCompleto = textos.join(' ');

      final precoRegex = RegExp(
        r'(?:R\$|BRL)\s?\d{1,3}(?:\.\d{3})*(?:,\d{2})?',
        caseSensitive: false,
      );

      final resultadoPreco = precoRegex.firstMatch(textoCompleto);

      if (resultadoPreco != null) {
        precoEncontrado = resultadoPreco.group(0) ?? '';
      }

      if (titulo.isEmpty) {
        titulo = 'Produto Shopee';
      }

      if (foto.isEmpty) {
        foto = '';
      }

      setState(() {
        produto = titulo;
        preco = precoEncontrado.isEmpty
            ? 'Preço não encontrado'
            : precoEncontrado;
        imagem = foto;
        linkFinal = resposta.request?.url.toString() ?? urlTexto;
        carregando = false;
      });
    } catch (e) {
      setState(() {
        carregando = false;
        erro =
            'Não foi possível carregar o produto automaticamente.\n\n'
            'A Shopee pode estar bloqueando o acesso automático ao produto. '
            'Tente novamente ou abra o link no navegador.';
      });
    }
  }

  String gerarTexto() {
    final nome = produto.isEmpty ? 'Produto Shopee' : produto;

    final valor = preco.isEmpty ? 'Consulte o preço' : preco;

    final link = linkFinal.isEmpty
        ? linkController.text.trim()
        : linkFinal;

    return '''
🔥 OFERTA SHOPEE 🔥

🛍️ $nome

💰 $valor

👉 COMPRE AQUI:
$link

⚡ Aproveite enquanto estiver disponível!
''';
  }

  Future<void> copiarDivulgacao() async {
    await Clipboard.setData(
      ClipboardData(text: gerarTexto()),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Divulgação copiada!'),
      ),
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
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const SizedBox(height: 15),

            TextField(
              controller: linkController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Link do produto Shopee',
                hintText: 'https://s.shopee.com.br/...',
                prefixIcon: const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),

            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton.icon(
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
                  carregando
                      ? 'CARREGANDO...'
                      : 'BUSCAR PRODUTO',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            if (erro.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.orange.shade300,
                  ),
                ),
                child: Text(
                  erro,
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontSize: 16,
                  ),
                ),
              ),

            const SizedBox(height: 20),

            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imagem.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.network(
                          imagem,
                          width: double.infinity,
                          height: 250,
                          fit: BoxFit.contain,
                          errorBuilder:
                              (context, error, stackTrace) {
                            return _imagemPadrao();
                          },
                        ),
                      )
                    else
                      _imagemPadrao(),

                    const SizedBox(height: 20),

                    const Text(
                      'PRODUTO',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      produto.isEmpty
                          ? 'Produto Shopee'
                          : produto,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'PREÇO',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      preco.isEmpty
                          ? 'Preço será carregado automaticamente'
                          : preco,
                      style: const TextStyle(
                        color: Colors.deepOrange,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    const Text(
                      'LINK DE DIVULGAÇÃO',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    SelectableText(
                      linkFinal.isEmpty
                          ? linkController.text
                          : linkFinal,
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 20),

                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton.icon(
                        onPressed: copiarDivulgacao,
                        icon: const Icon(Icons.copy),
                        label: const Text(
                          'GERAR DIVULGAÇÃO',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _imagemPadrao() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Center(
        child: Icon(
          Icons.image,
          size: 70,
          color: Colors.grey,
        ),
      ),
    );
  }
}
