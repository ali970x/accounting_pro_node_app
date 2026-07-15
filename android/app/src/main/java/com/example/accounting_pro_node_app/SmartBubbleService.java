package com.example.accounting_pro_node_app;

import android.app.Service;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.IBinder;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.WindowManager;
import android.widget.LinearLayout;
import android.widget.TextView;

public class SmartBubbleService extends Service {
    private static final String SMART_CLIPBOARD_ACTION = "com.example.accounting_pro_node_app.SMART_IMPORT_CLIPBOARD";
    private static boolean running = false;

    private WindowManager windowManager;
    private View bubbleView;
    private View removeTarget;
    private View confirmView;
    private WindowManager.LayoutParams bubbleParams;
    private int initialX;
    private int initialY;
    private float initialTouchX;
    private float initialTouchY;
    private long downTime;
    private int touchSlop;

    public static boolean isRunning() {
        return running;
    }

    @Override
    public void onCreate() {
        super.onCreate();
        running = true;
        touchSlop = ViewConfiguration.get(this).getScaledTouchSlop();
        windowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        addBubble();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (bubbleView == null) addBubble();
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        removeView(bubbleView);
        removeView(removeTarget);
        removeView(confirmView);
        bubbleView = null;
        removeTarget = null;
        confirmView = null;
        running = false;
        super.onDestroy();
    }

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    private void addBubble() {
        if (windowManager == null || bubbleView != null) return;

        TextView bubble = new TextView(this);
        bubble.setText("S");
        bubble.setTextColor(Color.WHITE);
        bubble.setTextSize(18);
        bubble.setTypeface(Typeface.DEFAULT_BOLD);
        bubble.setGravity(Gravity.CENTER);
        bubble.setElevation(dp(8));
        GradientDrawable background = new GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                new int[]{Color.rgb(15, 118, 110), Color.rgb(37, 99, 235)}
        );
        background.setShape(GradientDrawable.OVAL);
        bubble.setBackground(background);
        bubble.setAlpha(0.96f);

        bubbleParams = new WindowManager.LayoutParams(
                dp(54),
                dp(54),
                overlayType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
        );
        bubbleParams.gravity = Gravity.TOP | Gravity.START;
        bubbleParams.x = dp(12);
        bubbleParams.y = dp(180);

        bubble.setOnTouchListener(this::handleBubbleTouch);
        bubbleView = bubble;
        windowManager.addView(bubbleView, bubbleParams);
    }

    private boolean handleBubbleTouch(View view, MotionEvent event) {
        switch (event.getAction()) {
            case MotionEvent.ACTION_DOWN:
                downTime = System.currentTimeMillis();
                initialX = bubbleParams.x;
                initialY = bubbleParams.y;
                initialTouchX = event.getRawX();
                initialTouchY = event.getRawY();
                view.animate().scaleX(1.08f).scaleY(1.08f).setDuration(100).start();
                return true;
            case MotionEvent.ACTION_MOVE:
                int dx = Math.round(event.getRawX() - initialTouchX);
                int dy = Math.round(event.getRawY() - initialTouchY);
                if (Math.abs(dx) > touchSlop || Math.abs(dy) > touchSlop) showRemoveTarget();
                bubbleParams.x = initialX + dx;
                bubbleParams.y = initialY + dy;
                windowManager.updateViewLayout(bubbleView, bubbleParams);
                updateRemoveTargetState(event.getRawY());
                return true;
            case MotionEvent.ACTION_UP:
            case MotionEvent.ACTION_CANCEL:
                view.animate().scaleX(1f).scaleY(1f).setDuration(100).start();
                int moveX = Math.round(event.getRawX() - initialTouchX);
                int moveY = Math.round(event.getRawY() - initialTouchY);
                boolean moved = Math.abs(moveX) > touchSlop || Math.abs(moveY) > touchSlop;
                boolean quickTap = !moved && System.currentTimeMillis() - downTime < 500;
                if (moved && isNearRemoveTarget(event.getRawY())) {
                    hideRemoveTarget();
                    showRemoveConfirmation();
                } else {
                    hideRemoveTarget();
                    snapToNearestSide();
                    if (quickTap) openSmartImport();
                }
                return true;
            default:
                return false;
        }
    }

    private void openSmartImport() {
        Intent intent = new Intent(this, MainActivity.class);
        intent.setAction(SMART_CLIPBOARD_ACTION);
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
        startActivity(intent);
    }

    private void snapToNearestSide() {
        if (bubbleView == null) return;
        int screenWidth = getResources().getDisplayMetrics().widthPixels;
        int bubbleWidth = bubbleView.getWidth() == 0 ? dp(54) : bubbleView.getWidth();
        int targetX = bubbleParams.x + bubbleWidth / 2 < screenWidth / 2
                ? dp(8)
                : screenWidth - bubbleWidth - dp(8);
        bubbleParams.x = Math.max(dp(8), targetX);
        windowManager.updateViewLayout(bubbleView, bubbleParams);
    }

    private void showRemoveTarget() {
        if (removeTarget != null || windowManager == null) return;
        TextView target = new TextView(this);
        target.setText("X");
        target.setTextColor(Color.WHITE);
        target.setTextSize(22);
        target.setTypeface(Typeface.DEFAULT_BOLD);
        target.setGravity(Gravity.CENTER);
        GradientDrawable bg = new GradientDrawable();
        bg.setShape(GradientDrawable.OVAL);
        bg.setColor(Color.rgb(185, 28, 28));
        target.setBackground(bg);
        target.setAlpha(0.84f);
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                dp(72),
                dp(72),
                overlayType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
        );
        params.gravity = Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL;
        params.y = dp(32);
        removeTarget = target;
        windowManager.addView(removeTarget, params);
    }

    private void hideRemoveTarget() {
        removeView(removeTarget);
        removeTarget = null;
    }

    private void updateRemoveTargetState(float rawY) {
        if (removeTarget == null) return;
        removeTarget.animate()
                .scaleX(isNearRemoveTarget(rawY) ? 1.18f : 1f)
                .scaleY(isNearRemoveTarget(rawY) ? 1.18f : 1f)
                .alpha(isNearRemoveTarget(rawY) ? 1f : 0.84f)
                .setDuration(80)
                .start();
    }

    private boolean isNearRemoveTarget(float rawY) {
        int screenHeight = getResources().getDisplayMetrics().heightPixels;
        return rawY > screenHeight - dp(150);
    }

    private void showRemoveConfirmation() {
        if (confirmView != null || windowManager == null) return;
        removeView(bubbleView);
        bubbleView = null;

        LinearLayout panel = new LinearLayout(this);
        panel.setOrientation(LinearLayout.VERTICAL);
        panel.setPadding(dp(18), dp(16), dp(18), dp(16));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(Color.WHITE);
        bg.setCornerRadius(dp(18));
        panel.setBackground(bg);
        panel.setElevation(dp(10));

        TextView title = new TextView(this);
        title.setText("Remove Smart button?");
        title.setTextColor(Color.rgb(17, 24, 39));
        title.setTextSize(16);
        title.setTypeface(Typeface.DEFAULT_BOLD);
        panel.addView(title);

        TextView body = new TextView(this);
        body.setText("You can turn it on again from daftr Settings.");
        body.setTextColor(Color.rgb(75, 85, 99));
        body.setTextSize(13);
        body.setPadding(0, dp(6), 0, dp(12));
        panel.addView(body);

        LinearLayout actions = new LinearLayout(this);
        actions.setGravity(Gravity.END);
        TextView cancel = actionButton("Cancel", Color.rgb(55, 65, 81));
        TextView remove = actionButton("Remove", Color.rgb(185, 28, 28));
        cancel.setOnClickListener(v -> {
            removeView(confirmView);
            confirmView = null;
            addBubble();
        });
        remove.setOnClickListener(v -> stopSelf());
        actions.addView(cancel);
        actions.addView(remove);
        panel.addView(actions);

        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.WRAP_CONTENT,
                WindowManager.LayoutParams.WRAP_CONTENT,
                overlayType(),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
        );
        params.gravity = Gravity.CENTER;
        confirmView = panel;
        windowManager.addView(confirmView, params);
    }

    private TextView actionButton(String text, int color) {
        TextView button = new TextView(this);
        button.setText(text);
        button.setTextColor(color);
        button.setTextSize(14);
        button.setTypeface(Typeface.DEFAULT_BOLD);
        button.setPadding(dp(12), dp(8), dp(12), dp(8));
        return button;
    }

    private void removeView(View view) {
        if (view == null || windowManager == null) return;
        try {
            windowManager.removeView(view);
        } catch (IllegalArgumentException ignored) {
            // View may already have been detached by Android.
        }
    }

    private int overlayType() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            return WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY;
        }
        return WindowManager.LayoutParams.TYPE_PHONE;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
