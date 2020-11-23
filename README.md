# AMXX-DrawTexture
Плагин предназначен для обводки триггеров на различных картах. Так-же позволяет создавать произвольные линии путём создания точек соединения. Будет полезен на таких модах как <i>Surf</i> и <i>KreedzJump</i><br><br>
На данный момент выделяет 2 типа триггеров:
1. trigger_push - выделяется и настраивается сторона выделения автоматически (есть возможность настроить выделение)
2. trigger_teleport - не выделяется автоматически (есть возможность настроить выделение)

<i>Можно добавить свои триггеры, поместив Classname триггера в массив <b>g_szEntityAllowed</b>.</i>

<h2>Основные возможности:</h2>
<ul>
<li>Обводка триггеров</li>
<li>Настройка обводки (цвет обводки, сторона обводки, настройка скорости для trigger_push)</li>
<li>Удаление триггера с карты</li>
<li>Создание набора точек, соединяющиеся линией в последовательности их создания</li>
<li>Настройка набора точек (цвет линии)</li>
</ul>

<h2>Требования:</h2>
<b>AmxModX 1.8.2 и выше</b><br>

<h2>Ограничения:</h2>
<b>Максимум выделенных объектов на карте - 32</b><br>
<b>Максимум <i>набора</i> точек на карте - 32</b><br>
<b>Максимум точек в наборе - 6</b><br>
<b>Флаг доступа - <i>ADMIN_BAN</i></b><br>

<h2>Использование:</h2>
В чате: /drawt<br>
В консоле: drawt<br>

<h3>Набор точек</h3>
<img src="https://img-host.ru/q3uC.jpg">
<img src="https://img-host.ru/bi1M.jpg">

<h3>Выделение триггеров</h3>
<img src="https://img-host.ru/UoHd.jpg">
<img src="https://img-host.ru/vQsH.jpg">
