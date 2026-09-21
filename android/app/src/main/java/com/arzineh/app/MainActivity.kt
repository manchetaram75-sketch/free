package com.arzineh.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBars
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.ArrowForward
import androidx.compose.material.icons.rounded.CandlestickChart
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.MoreHoriz
import androidx.compose.material.icons.rounded.NotificationsNone
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.SwapHoriz
import androidx.compose.material.icons.rounded.SwapVert
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.text.NumberFormat
import java.util.Locale
import kotlin.math.roundToInt

private val Ink = Color(0xFF090C12)
private val Panel = Color(0xFF111620)
private val PanelRaised = Color(0xFF19212E)
private val Line = Color(0xFF28303E)
private val Muted = Color(0xFF8D96A6)
private val Faint = Color(0xFF5C6575)
private val Mint = Color(0xFF73E6B2)
private val Gold = Color(0xFFFFC15C)
private val Violet = Color(0xFFA78BFA)
private val Red = Color(0xFFFB7185)

private data class Rate(
    val code: String,
    val name: String,
    val price: Long,
    val change: Double,
    val crypto: Boolean,
    val symbol: String,
    val color: Color
)

private val rates = listOf(
    Rate("USD", "دلار آمریکا", 92450, .8, false, "$", Gold),
    Rate("EUR", "یورو اروپا", 108760, 1.2, false, "€", Color(0xFF89B4FA)),
    Rate("GBP", "پوند انگلیس", 126340, -.3, false, "£", Color(0xFFF38BA8)),
    Rate("AED", "درهم امارات", 25180, .6, false, "د", Color(0xFFE6A96B)),
    Rate("TRY", "لیر ترکیه", 2710, -1.1, false, "₺", Color(0xFFF38BA8)),
    Rate("CNY", "یوان چین", 12740, .4, false, "¥", Color(0xFFE6A96B)),
    Rate("JPY", "ین ژاپن", 620, -.2, false, "¥", Color(0xFFE6A96B)),
    Rate("CAD", "دلار کانادا", 68120, .9, false, "C$", Color(0xFF89B4FA)),
    Rate("AUD", "دلار استرالیا", 60280, .5, false, "A$", Color(0xFF89B4FA)),
    Rate("INR", "روپیه هند", 1105, -.4, false, "₹", Color(0xFFC6A0F6)),
    Rate("RUB", "روبل روسیه", 1010, 1.1, false, "₽", Color(0xFFC6A0F6)),
    Rate("SAR", "ریال عربستان", 24650, .3, false, "ر", Color(0xFF8BD5CA)),
    Rate("BTC", "بیت‌کوین", 10480000000, 2.4, true, "₿", Violet),
    Rate("ETH", "اتریوم", 486500000, 1.7, true, "◆", Color(0xFF8BD5CA)),
    Rate("USDT", "تتر", 92590, .1, true, "₮", Mint),
    Rate("SOL", "سولانا", 12740000, 3.8, true, "≋", Color(0xFFC6A0F6))
)

private fun formatToman(value: Double): String =
    NumberFormat.getNumberInstance(Locale("fa", "IR")).format(value.roundToInt())

private fun formatChange(value: Double): String =
    "${if (value >= 0) "+" else ""}${NumberFormat.getNumberInstance(Locale("fa", "IR")).format(value)}٪"

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent { ArzineTheme { ArzineApp() } }
    }
}

@Composable
private fun ArzineTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = darkColorScheme(
            primary = Mint,
            background = Ink,
            surface = Panel,
            onBackground = Color(0xFFF2F4F8),
            onSurface = Color(0xFFF2F4F8)
        ),
        content = content
    )
}

@Composable
private fun ArzineApp() {
    var screen by remember { mutableIntStateOf(0) }
    Surface(modifier = Modifier.fillMaxSize(), color = Ink) {
        androidx.compose.runtime.CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
            Scaffold(
                containerColor = Ink,
                bottomBar = {
                    BottomNavigation(selected = screen, onSelect = { screen = it })
                }
            ) { padding ->
                AnimatedContent(
                    targetState = screen,
                    modifier = Modifier.fillMaxSize().padding(padding),
                    transitionSpec = { fadeIn(tween(250)) togetherWith fadeOut(tween(160)) },
                    label = "screen transition"
                ) { selected ->
                    when (selected) {
                        0 -> HomeScreen(onOpen = { screen = it })
                        1 -> RatesScreen()
                        2 -> ConverterScreen()
                        else -> MoreScreen()
                    }
                }
            }
        }
    }
}

@Composable
private fun AppHeader() {
    Row(
        modifier = Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            LogoMark(Modifier.size(41.dp))
            Spacer(Modifier.width(10.dp))
            Column {
                Text("ارزینه", fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
                Text("نرخ‌یار هوشمند", fontSize = 10.sp, color = Muted)
            }
        }
        Box {
            IconButton(
                onClick = {},
                modifier = Modifier.size(42.dp).clip(RoundedCornerShape(14.dp)).background(Color.White.copy(alpha = .06f))
            ) { Icon(Icons.Rounded.NotificationsNone, "اعلان‌ها", tint = Color(0xFFDCE2EA)) }
            Box(Modifier.size(6.dp).align(Alignment.TopEnd).offset(x = (-9).dp, y = 8.dp).clip(CircleShape).background(Gold))
        }
    }
}

@Composable
private fun LogoMark(modifier: Modifier = Modifier) {
    Box(modifier.clip(RoundedCornerShape(14.dp)).background(Color(0xFF16211F)), contentAlignment = Alignment.Center) {
        Text("◔", color = Gold, fontSize = 27.sp, fontWeight = FontWeight.Bold)
        Text("ر", color = Mint, fontSize = 19.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.padding(start = 12.dp, top = 1.dp))
    }
}

@Composable
private fun HomeScreen(onOpen: (Int) -> Unit) {
    LazyColumn(
        modifier = Modifier.fillMaxSize(),
        contentPadding = PaddingValues(bottom = 22.dp),
        verticalArrangement = Arrangement.spacedBy(0.dp)
    ) {
        item { AppHeader() }
        item { HeroCard(onOpen) }
        item { MarketStrip() }
        item { SectionHeading("ارزهای محبوب", "منتخب امروز", "همه نرخ‌ها") { onOpen(1) } }
        item {
            Row(Modifier.fillMaxWidth().padding(horizontal = 18.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                FeaturedRate(rates[0], Modifier.weight(1f))
                FeaturedRate(rates[5], Modifier.weight(1f))
            }
        }
        item { Spacer(Modifier.height(29.dp)) }
        item { SectionHeading("تبدیلگر ارز", "سریع و دقیق", "باز کردن") { onOpen(2) } }
        item { ConverterPreview(onOpen) }
    }
}

@Composable
private fun HeroCard(onOpen: (Int) -> Unit) {
    val transition = rememberInfiniteTransition(label = "hero pulse")
    val drift by transition.animateFloat(0f, 8f, infiniteRepeatable(tween(2500), RepeatMode.Reverse), label = "token drift")
    Box(
        modifier = Modifier.padding(horizontal = 18.dp).fillMaxWidth().height(222.dp).clip(RoundedCornerShape(26.dp))
            .background(Brush.linearGradient(listOf(Color(0xFF202B3B), Color(0xFF111722))))
            .border(1.dp, Color.White.copy(alpha = .1f), RoundedCornerShape(26.dp))
    ) {
        Canvas(Modifier.fillMaxSize()) {
            drawCircle(Color.Transparent, radius = 108.dp.toPx(), center = Offset(size.width * .87f, size.height * .05f), style = Stroke(1.dp.toPx(), Color.White.copy(alpha = .1f)))
            drawCircle(Color.Transparent, radius = 78.dp.toPx(), center = Offset(size.width * .87f, size.height * .05f), style = Stroke(1.dp.toPx(), Gold.copy(alpha = .13f)))
            val path = Path().apply { moveTo(size.width - 75.dp.toPx(), 38.dp.toPx()); cubicTo(size.width - 155.dp.toPx(), 65.dp.toPx(), size.width - 115.dp.toPx(), 128.dp.toPx(), size.width - 210.dp.toPx(), 145.dp.toPx()) }
            drawPath(path, Mint.copy(alpha = .19f), style = Stroke(1.dp.toPx(), cap = StrokeCap.Round))
        }
        Column(Modifier.padding(horizontal = 24.dp, vertical = 25.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(6.dp).clip(CircleShape).background(Mint))
                Spacer(Modifier.width(7.dp))
                Text("به‌روزرسانی لحظه‌ای", color = Mint, fontSize = 10.sp, fontWeight = FontWeight.SemiBold)
            }
            Text("نبض بازار\nدر دستان تو", fontSize = 27.sp, lineHeight = 38.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.padding(top = 8.dp))
            Text("قیمت ارزها را ساده و سریع دنبال کن.", fontSize = 11.sp, color = Color(0xFFAAB2C1))
            SmallPrimaryButton("مشاهده نرخ‌ها", Modifier.padding(top = 15.dp)) { onOpen(1) }
        }
        TokenBubble("$", Gold, 64.dp, Modifier.align(Alignment.TopEnd).padding(top = 43.dp, end = 36.dp).offset(y = drift.dp))
        TokenBubble("₿", Violet, 38.dp, Modifier.align(Alignment.BottomEnd).padding(bottom = 48.dp, end = 124.dp).offset(y = (-drift / 2).dp))
        TokenBubble("€", Mint, 27.dp, Modifier.align(Alignment.BottomEnd).padding(bottom = 47.dp, end = 26.dp))
    }
}

@Composable
private fun TokenBubble(label: String, color: Color, size: androidx.compose.ui.unit.Dp, modifier: Modifier) {
    Box(modifier.size(size).clip(CircleShape).background(color.copy(alpha = .95f)), contentAlignment = Alignment.Center) {
        Text(label, color = Ink, fontWeight = FontWeight.ExtraBold, fontSize = (size.value / 2.1f).sp)
    }
}

@Composable
private fun SmallPrimaryButton(label: String, modifier: Modifier = Modifier, onClick: () -> Unit) {
    Row(modifier = modifier.height(38.dp).clip(RoundedCornerShape(11.dp)).background(Mint).clickable { onClick() }.padding(horizontal = 15.dp), verticalAlignment = Alignment.CenterVertically) {
        Text(label, color = Color(0xFF10251D), fontSize = 11.sp, fontWeight = FontWeight.Bold)
        Spacer(Modifier.width(7.dp))
        Icon(Icons.Rounded.ArrowBack, null, tint = Color(0xFF10251D), modifier = Modifier.size(16.dp))
    }
}

@Composable
private fun MarketStrip() {
    Row(Modifier.fillMaxWidth().padding(horizontal = 18.dp, vertical = 13.dp).height(54.dp).clip(RoundedCornerShape(16.dp)).background(Color.White.copy(alpha = .03f)).border(1.dp, Color.White.copy(alpha = .06f), RoundedCornerShape(16.dp)).padding(horizontal = 15.dp), verticalAlignment = Alignment.CenterVertically) {
        Row(verticalAlignment = Alignment.CenterVertically) { Box(Modifier.size(5.dp).clip(CircleShape).background(Mint)); Spacer(Modifier.width(8.dp)); Text("بازار امروز", color = Muted, fontSize = 10.sp) }
        Spacer(Modifier.weight(1f))
        Column(horizontalAlignment = Alignment.End) { Text("+۲.۴٪", color = Mint, fontSize = 11.sp, fontWeight = FontWeight.Bold); Text("روند کلی بازار", color = Faint, fontSize = 8.sp) }
        Spacer(Modifier.width(10.dp)); MiniChart()
    }
}

@Composable
private fun MiniChart() {
    Canvas(Modifier.width(105.dp).height(30.dp)) {
        val points = listOf(.9f, .75f, .78f, .48f, .58f, .25f, .1f).mapIndexed { i, v -> Offset(i * size.width / 6, v * size.height) }
        val path = Path().apply { moveTo(points.first().x, points.first().y); points.drop(1).forEach { lineTo(it.x, it.y) } }
        drawPath(path, Mint, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round))
    }
}

@Composable
private fun SectionHeading(title: String, kicker: String, action: String, onAction: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(horizontal = 18.dp).padding(top = 15.dp, bottom = 13.dp), horizontalArrangement = Arrangement.SpaceBetween, verticalAlignment = Alignment.Bottom) {
        Column { Text(kicker, color = Muted, fontSize = 10.sp); Text(title, fontSize = 20.sp, fontWeight = FontWeight.ExtraBold) }
        Text(action + "  ←", color = Mint, fontSize = 10.sp, modifier = Modifier.clickable { onAction() }.padding(4.dp))
    }
}

@Composable
private fun FeaturedRate(rate: Rate, modifier: Modifier = Modifier) {
    Column(modifier.height(165.dp).clip(RoundedCornerShape(20.dp)).background(Brush.linearGradient(listOf(rate.color.copy(alpha = .16f), rate.color.copy(alpha = .025f)))).border(1.dp, Color.White.copy(alpha = .08f), RoundedCornerShape(20.dp)).padding(14.dp)) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { AssetPill(rate); Text(formatChange(rate.change), color = Mint, fontSize = 9.sp) }
        Spacer(Modifier.height(15.dp)); Text(rate.name, fontSize = 11.sp, fontWeight = FontWeight.SemiBold); Text(rate.code, fontSize = 8.sp, color = Muted)
        Text(formatToman(rate.price.toDouble()), fontSize = 15.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.padding(top = 3.dp)); Text("تومان", fontSize = 8.sp, color = Muted)
        Spacer(Modifier.weight(1f)); MiniChart()
    }
}

@Composable
private fun AssetPill(rate: Rate) {
    Box(Modifier.size(31.dp).clip(RoundedCornerShape(11.dp)).background(rate.color.copy(alpha = .18f)), contentAlignment = Alignment.Center) { Text(rate.symbol, color = rate.color, fontSize = 16.sp, fontWeight = FontWeight.ExtraBold) }
}

@Composable
private fun ConverterPreview(onOpen: (Int) -> Unit) {
    Column(Modifier.padding(horizontal = 18.dp).fillMaxWidth().clip(RoundedCornerShape(20.dp)).background(Panel).border(1.dp, Color.White.copy(alpha = .08f), RoundedCornerShape(20.dp)).padding(15.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            AssetPill(rates[0]); Spacer(Modifier.width(8.dp)); Column { Text("از", color = Muted, fontSize = 9.sp); Text("دلار آمریکا", fontSize = 10.sp, fontWeight = FontWeight.SemiBold) }; Spacer(Modifier.weight(1f)); Text("۱", fontSize = 20.sp, fontWeight = FontWeight.ExtraBold)
        }
        Row(Modifier.fillMaxWidth().padding(vertical = 8.dp), horizontalArrangement = Arrangement.Center) { Box(Modifier.size(28.dp).clip(RoundedCornerShape(9.dp)).background(PanelRaised).border(1.dp, Line, RoundedCornerShape(9.dp)), contentAlignment = Alignment.Center) { Icon(Icons.Rounded.SwapVert, null, tint = Mint, modifier = Modifier.size(17.dp)) } }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(Modifier.size(31.dp).clip(RoundedCornerShape(11.dp)).background(Mint.copy(alpha = .17f)), contentAlignment = Alignment.Center) { Text("﷼", color = Mint, fontSize = 16.sp, fontWeight = FontWeight.Bold) }; Spacer(Modifier.width(8.dp)); Column { Text("به", color = Muted, fontSize = 9.sp); Text("تومان ایران", fontSize = 10.sp, fontWeight = FontWeight.SemiBold) }; Spacer(Modifier.weight(1f)); Text("۹۲,۴۵۰", fontSize = 18.sp, fontWeight = FontWeight.ExtraBold)
        }
        Row(Modifier.fillMaxWidth().height(40.dp).padding(top = 9.dp).clip(RoundedCornerShape(12.dp)).background(Mint.copy(alpha = .1f)).clickable { onOpen(2) }, horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) { Text("شروع تبدیل  ←", color = Mint, fontSize = 11.sp, fontWeight = FontWeight.Bold) }
    }
}

@Composable
private fun RatesScreen() {
    var tab by remember { mutableIntStateOf(0) }
    var query by remember { mutableStateOf("") }
    val shown = rates.filter { (tab == 0 || (tab == 1 && !it.crypto) || (tab == 2 && it.crypto)) && (query.isBlank() || it.name.contains(query) || it.code.contains(query, true)) }
    LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 20.dp)) {
        item {
            Column(Modifier.padding(horizontal = 20.dp, vertical = 20.dp)) { Text("رصد لحظه‌ای", color = Muted, fontSize = 10.sp); Text("نرخ بازار", fontSize = 28.sp, fontWeight = FontWeight.ExtraBold); Text("قیمت‌ها به تومان، آخرین بروزرسانی همین حالا", color = Muted, fontSize = 11.sp, modifier = Modifier.padding(top = 6.dp)) }
            Row(Modifier.padding(horizontal = 18.dp).fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Row(Modifier.weight(1f).height(44.dp).clip(RoundedCornerShape(13.dp)).background(Panel).border(1.dp, Line, RoundedCornerShape(13.dp)).padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) { Icon(Icons.Rounded.Search, null, tint = Muted, modifier = Modifier.size(18.dp)); Spacer(Modifier.width(7.dp)); androidx.compose.foundation.text.BasicTextField(value = query, onValueChange = { query = it }, singleLine = true, textStyle = MaterialTheme.typography.bodySmall.copy(color = Color.White), modifier = Modifier.fillMaxWidth(), decorationBox = { inner -> if (query.isEmpty()) Text("جستجوی ارز...", color = Faint, fontSize = 11.sp); inner() }) }
                Spacer(Modifier.width(9.dp)); Box(Modifier.size(44.dp).clip(RoundedCornerShape(13.dp)).background(Panel).border(1.dp, Line, RoundedCornerShape(13.dp)), contentAlignment = Alignment.Center) { Icon(Icons.Rounded.Tune, null, tint = Mint, modifier = Modifier.size(18.dp)) }
            }
            Row(Modifier.padding(horizontal = 18.dp, vertical = 15.dp).fillMaxWidth().height(43.dp).clip(RoundedCornerShape(13.dp)).background(Panel).padding(4.dp)) { listOf("همه", "ارزها", "دیجیتال").forEachIndexed { index, label -> val selected = index == tab; Box(Modifier.weight(1f).fillMaxSize().clip(RoundedCornerShape(10.dp)).background(if (selected) PanelRaised else Color.Transparent).clickable { tab = index }, contentAlignment = Alignment.Center) { Text(label, color = if (selected) Color.White else Muted, fontSize = 11.sp) } } }
        }
        items(shown, key = { it.code }) { rate -> RateRow(rate) }
        item { Row(Modifier.fillMaxWidth().padding(top = 18.dp), horizontalArrangement = Arrangement.Center, verticalAlignment = Alignment.CenterVertically) { Box(Modifier.size(5.dp).clip(CircleShape).background(Mint)); Spacer(Modifier.width(8.dp)); Text("آخرین بروزرسانی: همین حالا", color = Faint, fontSize = 9.sp) } }
    }
}

@Composable
private fun RateRow(rate: Rate) {
    Row(Modifier.padding(horizontal = 18.dp, vertical = 4.dp).fillMaxWidth().height(65.dp).clip(RoundedCornerShape(16.dp)).background(Panel).border(1.dp, Color.White.copy(alpha = .06f), RoundedCornerShape(16.dp)).padding(horizontal = 13.dp), verticalAlignment = Alignment.CenterVertically) {
        AssetPill(rate); Spacer(Modifier.width(10.dp)); Column { Text(rate.name, fontSize = 11.sp, fontWeight = FontWeight.SemiBold); Text(rate.code, color = Muted, fontSize = 9.sp) }; Spacer(Modifier.weight(1f)); Text(formatChange(rate.change), color = if (rate.change >= 0) Mint else Red, fontSize = 9.sp); Spacer(Modifier.width(11.dp)); Column(horizontalAlignment = Alignment.End) { Text(formatToman(rate.price.toDouble()), fontSize = 12.sp, fontWeight = FontWeight.Bold); Text("تومان", color = Muted, fontSize = 9.sp) }
    }
}

@Composable
private fun ConverterScreen() {
    var amount by remember { mutableStateOf("1") }
    var from by remember { mutableStateOf(rates[0]) }
    val numericAmount = amount.toDoubleOrNull() ?: 0.0
    LazyColumn(modifier = Modifier.fillMaxSize(), contentPadding = PaddingValues(bottom = 20.dp)) {
        item {
            Column(Modifier.padding(horizontal = 20.dp, vertical = 20.dp)) { Text("ساده، سریع، مطمئن", color = Muted, fontSize = 10.sp); Text("تبدیلگر", fontSize = 28.sp, fontWeight = FontWeight.ExtraBold); Text("ارزش ارزها را به تومان محاسبه کن.", color = Muted, fontSize = 11.sp, modifier = Modifier.padding(top = 6.dp)) }
            Column(Modifier.padding(horizontal = 18.dp).fillMaxWidth().clip(RoundedCornerShape(24.dp)).background(Brush.linearGradient(listOf(Color(0xFF151D29), Color(0xFF10151E)))).border(1.dp, Color.White.copy(alpha = .1f), RoundedCornerShape(24.dp)).padding(18.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text("مقدار", color = Muted, fontSize = 10.sp); Text("نرخ لحظه‌ای", color = Mint, fontSize = 9.sp) }
                Row(Modifier.fillMaxWidth().height(65.dp).padding(top = 9.dp).clip(RoundedCornerShape(15.dp)).background(Mint.copy(alpha = .06f)).border(1.dp, Mint.copy(alpha = .23f), RoundedCornerShape(15.dp)).padding(horizontal = 15.dp), verticalAlignment = Alignment.CenterVertically) {
                    androidx.compose.foundation.text.BasicTextField(value = amount, onValueChange = { amount = it }, singleLine = true, textStyle = MaterialTheme.typography.headlineMedium.copy(color = Color.White, fontWeight = FontWeight.ExtraBold, textAlign = TextAlign.Left), modifier = Modifier.weight(1f)); Text(from.code, color = Mint, fontSize = 11.sp)
                }
                CurrencyPicker(rate = from, label = "از ارز", onClick = { from = if (from.code == "USD") rates[5] else rates[0] })
                CurrencyPicker(rate = Rate("IRR", "تومان ایران", 1, 0.0, false, "﷼", Mint), label = "به ارز", onClick = {})
                Column(Modifier.fillMaxWidth().padding(top = 13.dp).clip(RoundedCornerShape(15.dp)).background(Mint.copy(alpha = .06f)).border(1.dp, Mint.copy(alpha = .2f), RoundedCornerShape(15.dp)).padding(14.dp)) { Text("ارزش تقریبی", color = Muted, fontSize = 9.sp); Text("${formatToman(numericAmount * from.price)} تومان", fontSize = 25.sp, fontWeight = FontWeight.ExtraBold, modifier = Modifier.padding(top = 5.dp)); Text("۱ ${from.code} = ${formatToman(from.price.toDouble())} تومان", color = Mint, fontSize = 9.sp, modifier = Modifier.padding(top = 3.dp)) }
            }
            Text("مقدار سریع", color = Muted, fontSize = 10.sp, modifier = Modifier.padding(start = 20.dp, top = 20.dp, bottom = 10.dp))
            Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 18.dp), horizontalArrangement = Arrangement.spacedBy(7.dp)) { listOf("۱", "۱۰", "۱۰۰", "۱,۰۰۰").forEach { value -> Box(Modifier.height(32.dp).width(60.dp).clip(RoundedCornerShape(10.dp)).background(Panel).border(1.dp, Line, RoundedCornerShape(10.dp)).clickable { amount = value.replace(",", "") }, contentAlignment = Alignment.Center) { Text(value, color = Color(0xFFBEC6D3), fontSize = 10.sp) } } }
            Row(Modifier.padding(horizontal = 18.dp, vertical = 20.dp).fillMaxWidth().clip(RoundedCornerShape(13.dp)).background(Gold.copy(alpha = .05f)).border(1.dp, Gold.copy(alpha = .13f), RoundedCornerShape(13.dp)).padding(12.dp), verticalAlignment = Alignment.Top) { Box(Modifier.size(16.dp).clip(CircleShape).border(1.dp, Gold), contentAlignment = Alignment.Center) { Text("i", color = Gold, fontSize = 10.sp) }; Spacer(Modifier.width(8.dp)); Text("نرخ‌ها از منابع معتبر بازار جمع‌آوری می‌شوند و برای معامله نهایی نیستند.", color = Muted, fontSize = 9.sp, lineHeight = 16.sp) }
        }
    }
}

@Composable
private fun CurrencyPicker(rate: Rate, label: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().padding(top = 12.dp).height(61.dp).clip(RoundedCornerShape(15.dp)).background(Color.White.copy(alpha = .025f)).border(1.dp, Line, RoundedCornerShape(15.dp)).clickable { onClick() }.padding(horizontal = 12.dp), verticalAlignment = Alignment.CenterVertically) { AssetPill(rate); Spacer(Modifier.width(10.dp)); Column { Text(label, color = Muted, fontSize = 9.sp); Text(rate.name, fontSize = 11.sp, fontWeight = FontWeight.SemiBold) }; Spacer(Modifier.weight(1f)); Text(rate.code, color = Muted, fontSize = 10.sp); Spacer(Modifier.width(12.dp)); Text("⌄", color = Muted, fontSize = 14.sp) }
}

@Composable
private fun MoreScreen() {
    Column(Modifier.fillMaxSize().padding(20.dp)) { Text("بیشتر", fontSize = 28.sp, fontWeight = FontWeight.ExtraBold); Text("ارزینه را برای خودت شخصی‌سازی کن.", color = Muted, fontSize = 11.sp, modifier = Modifier.padding(top = 6.dp)); Spacer(Modifier.height(22.dp)); listOf("درباره ارزینه", "واحد پول پیش‌فرض", "اعلان تغییر قیمت").forEach { label -> Row(Modifier.fillMaxWidth().height(58.dp).padding(vertical = 4.dp).clip(RoundedCornerShape(15.dp)).background(Panel).padding(horizontal = 15.dp), verticalAlignment = Alignment.CenterVertically) { Text(label, fontSize = 11.sp); Spacer(Modifier.weight(1f)); Icon(Icons.Rounded.ArrowForward, null, tint = Faint, modifier = Modifier.size(17.dp)) } } }
}

@Composable
private fun BottomNavigation(selected: Int, onSelect: (Int) -> Unit) {
    Row(Modifier.fillMaxWidth().windowInsetsPadding(WindowInsets.navigationBars).height(78.dp).padding(horizontal = 18.dp, vertical = 7.dp).clip(RoundedCornerShape(22.dp)).background(Color(0xE0141A24)).border(1.dp, Color.White.copy(alpha = .1f), RoundedCornerShape(22.dp)), horizontalArrangement = Arrangement.SpaceAround, verticalAlignment = Alignment.CenterVertically) {
        val navItems = listOf(Triple("خانه", Icons.Rounded.Home, 0), Triple("نرخ‌ها", Icons.Rounded.CandlestickChart, 1), Triple("تبدیلگر", Icons.Rounded.SwapHoriz, 2), Triple("بیشتر", Icons.Rounded.MoreHoriz, 3))
        navItems.forEach { (label, icon, index) -> val active = selected == index; val tint by animateColorAsState(if (active) Mint else Faint, label = "nav tint"); Column(Modifier.width(64.dp).height(62.dp).clip(RoundedCornerShape(12.dp)).clickable { onSelect(index) }, horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) { Box(Modifier.size(28.dp).clip(RoundedCornerShape(10.dp)).background(if (active) Mint.copy(alpha = .1f) else Color.Transparent), contentAlignment = Alignment.Center) { Icon(icon, label, tint = tint, modifier = Modifier.size(19.dp)) }; Text(label, color = tint, fontSize = 9.sp, modifier = Modifier.padding(top = 4.dp)) } }
    }
}
