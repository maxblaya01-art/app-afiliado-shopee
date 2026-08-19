import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

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
  final TextEditingController linkController =
      TextEditingController();

  late final WebViewController webViewController;

  bool carregando = false;

  String erro = '';
  String produto = '';
  String preco = '';
  String imagem = '';
  String linkFinal = '';

  @override
  void initState() {
    super.initState();

    webViewController = WebViewController()
      ..setJavaScriptMode(
        JavaScriptMode.unrestricted,
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            if (mounted) {
              setState(() {
                carregando = true;
              });
            }
          },
          onPageFinished: (url) {
            _lerProduto(url);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                carregando = false;
                erro =
                    'A Shopee bloqueou a leitura automática. '
                    'Você pode abrir o produto na Shopee.';
              });
            }
          },
        ),
      );
  }

  bool _ehLinkShopee(String valor) {
    final uri = Uri.tryParse(valor);

    if (uri == null) {
      return false;
    }

    return uri.host.toLowerCase().contains('shopee.com.br');
  }

  Future<void> _buscarProduto() async {
    String valor = linkController.text.trim();

    if (valor.isEmpty) {
      setState(() {
        erro = 'Cole o link do produto da Shopee.';
      });
      return;
    }

    if (!valor.startsWith('http://') &&
        !valor.startsWith('https://')) {
      valor = 'https://$valor';
    }

    if (!_ehLinkShopee(valor)) {
      setState(() {
        erro = 'Cole um link válido da Shopee.';
      });
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      carregando = true;
      erro = '';
      produto = '';
      preco = '';
      imagem = '';
      linkFinal = valor;
    });

    try {
      await webViewController.loadRequest(
        Uri.parse(valor),
      );
    } catch (e) {
      setState(() {
        carregando = false;
        erro = 'Não foi possível abrir o link.';
      });
    }
  }

  Future<void> _lerProduto(String url) async {
    try {
      await Future.delayed(
        const Duration(seconds: 2),
      );

      final resultado =
          await webViewController.runJavaScriptReturningResult(
        r'''
(() => {
  const obter = (seletor, atributo = 'content') => {
    const elemento = document.querySelector(seletor);

    if (!elemento) {
      return '';
    }

    return elemento.getAttribute(atributo) ||
           elemento.textContent ||
           '';
  };

  return JSON.stringify({
    titulo: obter('meta[property="og:title"]'),
    imagem: obter('meta[property="og:image"]'),
    preco: obter('meta[property="product:price:amount"]'),
    canonico: obter('link[rel="canonical"]', 'href'),
    url: window.location.href
  });
})();
''',
      );

      String texto = resultado.toString();

      if (texto.startsWith('"')) {
        texto = jsonDecode(texto);
      }

      final dados =
          jsonDecode(texto) as Map<String, dynamic>;

      if (!mounted) {
        return;
      }

      setState(() {
        produto =
            (dados['titulo'] ?? '').toString().trim();

        if (produto.isEmpty) {
          produto = 'Produto Shopee';
        }

        final valorPreco =
            (dados['preco'] ?? '').toString().trim();

        if (valorPreco.isEmpty) {
          preco = 'Preço não disponível';
        } else {
          preco = 'R\$ $valorPreco';
        }

        imagem =
            (dados['imagem'] ?? '').toString().trim();

        final linkCanonico =
            (dados['canonico'] ?? '').toString().trim();

        if (linkCanonico.isNotEmpty) {
          linkFinal = linkCanonico;
        } else {
          linkFinal = url;
        }

        carregando = false;
        erro = '';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        carregando = false;
        erro =
            'A Shopee bloqueou a leitura automática. '
            'Use o botão ABRIR NA SHOPEE.';
        
        if (produto.isEmpty) {
          produto = 'Produto Shopee';
        }

        if (preco.isEmpty) {
          preco = 'Preço não disponível';
        }
      });
    }
  }

  Future<void> _abrirShopee() async {
    final valor =
        linkFinal.isNotEmpty
            ? linkFinal
            : linkController.text.trim();

    final uri = Uri.tryParse(valor);

    if (uri != null) {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    }
  }

  Future<void> _gerarDivulgacao() async {
    final nome =
        produto.isEmpty ? 'Oferta Shopee' : produto;

    final valorPreco =
        preco.isEmpty ? 'Confira o preço' : preco;

    final valorLink =
        linkFinal.isEmpty
            ? linkController.text.trim()
            : linkFinal;

    final texto = '''
🔥 $nome

💰 $valorPreco

🛒 COMPRE AQUI:
$valorLink
''';

    await Clipboard.setData(
      ClipboardData(text: texto),
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Divulgação copiada!',
        ),
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
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
        title: const Text(
          'Divulgador Shopee',
          style: TextStyle(
            color: Colors.white,
            fontSize: 27,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: linkController,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText:
                    'Link do produto Shopee',
                hintText:
                    'https://s.shopee.com.br/...',
                prefixIcon:
                    const Icon(Icons.link),
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(18),
                ),
              ),
            ),

            const SizedBox(height: 15),

            ElevatedButton.icon(
              onPressed:
                  carregando
                      ? null
                      : _buscarProduto,
              icon: const Icon(Icons.search),
              label: Text(
                carregando
                    ? 'CARREGANDO...'
                    : 'BUSCAR PRODUTO',
              ),
              style:
                  ElevatedButton.styleFrom(
                minimumSize:
                    const Size.fromHeight(58),
              ),
            ),

            if (erro.isNotEmpty) ...[
              const SizedBox(height: 18),

              Container(
                padding:
                    const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color:
                      Colors.orange.shade50,
                  borderRadius:
                      BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  erro,
                  style: TextStyle(
                    color:
                        Colors.deepOrange.shade700,
                    fontSize: 17,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 22),

            Card(
              elevation: 3,
              child: Padding(
                padding:
                    const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 240,
                      child: imagem.isEmpty
                          ? Container(
                              color:
                                  Colors.grey.shade200,
                              child:
                                  const Icon(
                                Icons
                                    .image_outlined,
                                size: 70,
                                color:
                                    Colors.grey,
                              ),
                            )
                          : Image.network(
                              imagem,
                              fit:
                                  BoxFit.contain,
                              errorBuilder:
                                  (
                                    context,
                                    error,
                                    stackTrace,
                                  ) {
                                return const Icon(
                                  Icons
                                      .broken_image_outlined,
                                  size: 70,
                                );
                              },
                            ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'PRODUTO',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      produto.isEmpty
                          ? 'Produto Shopee'
                          : produto,
                      style:
                          const TextStyle(
                        fontSize: 23,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      'PREÇO',
                      style: TextStyle(
                        color: Colors.grey,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      preco.isEmpty
                          ? 'Preço será carregado automaticamente'
                          : preco,
                      style:
                          const TextStyle(
                        color:
                            Colors.deepOrange,
                        fontSize: 22,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    OutlinedButton.icon(
                      onPressed:
                          _abrirShopee,
                      icon: const Icon(
                        Icons.open_in_new,
                      ),
                      label: const Text(
                        'ABRIR NA SHOPEE',
                      ),
                      style:
                          OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(
                          52,
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    ElevatedButton.icon(
                      onPressed:
                          _gerarDivulgacao,
                      icon: const Icon(
                        Icons.copy,
                      ),
                      label: const Text(
                        'GERAR DIVULGAÇÃO',
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(
                          52,
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
