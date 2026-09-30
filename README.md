# Livoca 🐼💖

App simples de organização pessoal feito em Flutter. Tudo fica salvo no próprio celular, sem backend.

## Funcionalidades

- **Primeiro acesso**: o usuário informa nome e idade (dá para editar depois no ícone de perfil).
- **Data de hoje** sempre visível no topo da tela principal.
- **Contador de tarefas concluídas** com filtro: Dia, Semana, Mês, Trimestre, Semestre, Ano ou Total.
- **Resumo do dia**: na primeira vez que o app é aberto no dia, aparece um resumo com as tarefas e
  compromissos de hoje (panda pensativo) e, em seguida, as tarefas não concluídas a tempo (panda triste).
- **Tarefas por período**: Hoje, Esta semana, Este mês, Este trimestre, Este semestre e Este ano.
- **Parabéns com confetes**: quando todas as tarefas de um período são concluídas, aparece uma tela
  de parabéns com o panda. A imagem pode ser **compartilhada** em outros apps.
- **Não realizadas a tempo**: tarefas não concluídas até o fim do período vão para essa seção.
- **Em pausa**: tarefas podem ser pausadas.
- **Arrastar e soltar**: segure uma tarefa (toque longo) e solte em outra fileira. Durante o arraste
  aparece uma barra na parte de baixo com todos os destinos (Dia, Semana, Mês, Trimestre, Semestre,
  Ano e Pausar), então não é preciso rolar a tela. Soltar uma tarefa pausada ou atrasada numa fileira
  a retoma naquele período. O menu `⋮` de cada tarefa tem as mesmas opções.
- **Agenda**: calendário com compromissos (data, hora e observação). O calendário também mostra o
  prazo final das tarefas.

## Como rodar

```bash
flutter pub get
flutter run
```

## Estrutura

```
lib/
  main.dart                  # inicialização, tema, idioma pt-BR
  models.dart                # períodos, tarefas, compromissos, perfil
  app_state.dart             # estado e persistência (shared_preferences)
  app_scope.dart             # acesso ao estado pela árvore de widgets
  theme.dart                 # cores rosa
  screens/
    onboarding_screen.dart   # nome e idade
    daily_briefing_screen.dart # resumo do dia
    home_shell.dart          # navegação Tarefas / Agenda
    tasks_screen.dart        # fileiras e arrastar-e-soltar
    celebration_screen.dart  # confetes e compartilhamento
    agenda_screen.dart       # calendário e compromissos
  widgets/
    panda.dart
    task_widgets.dart
```

## Créditos das imagens

As ilustrações do panda são de **domínio público (CC0)**, do [OpenClipart](https://openclipart.org):

- [Cute Cartoon Panda](https://openclipart.org/detail/279984/cute-cartoon-panda) — `assets/images/panda.svg` (também usada no ícone do app)
- [Panda with a Heart](https://openclipart.org/detail/300655/panda-with-a-heart) — `assets/images/panda_heart.svg`
- [Sad Panda](https://openclipart.org/detail/312494/sad-panda) — `assets/images/panda_sad.svg`
- `assets/images/panda_thinking.svg` — derivado do "Cute Cartoon Panda", com um balão de checklist adicionado
