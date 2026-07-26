package com.walkingrpg.walking_rpg_mobile

import android.app.Activity
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class HealthPermissionsRationaleActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val density = resources.displayMetrics.density
        val padding = (24 * density).toInt()
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(padding, padding, padding, padding)
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }
        layout.addView(TextView(this).apply {
            text = "Доступ к шагам"
            textSize = 24f
        })
        layout.addView(TextView(this).apply {
            text = "Walking RPG читает только суммарное количество шагов за текущий день, чтобы начислить игровую энергию. Приложение не запрашивает пульс, сон, вес, геолокацию или медицинские записи. На backend отправляются локальная дата, часовой пояс и итоговое число шагов. Данные здоровья не используются для рекламы."
            textSize = 16f
            setPadding(0, padding / 2, 0, padding)
        })
        layout.addView(Button(this).apply {
            text = "Понятно"
            setOnClickListener { finish() }
        })
        setContentView(layout)
    }
}
