from database import SessionLocal, engine, Base
import models

# ۱. ساخت تمام جداول
Base.metadata.create_all(bind=engine)

db = SessionLocal()

try:
    # ۲. ثبت یا دریافت مدل محصول
    model = db.query(models.ProductModel).filter_by(code="GSS-R7638").first()
    if not model:
        model = models.ProductModel(
            code="GSS-R7638",
            title="یخچال فریزر ساید بای ساید",
            description="مدل پایه جهت تست"
        )
        db.add(model)
        db.commit()
        db.refresh(model)

    # ۳. حذف استانداردهای قبلی برای جلوگیری از همپوشانی
    db.query(models.ModelSpecification).filter_by(
        model_id=model.id, 
        station_code="ABS"
    ).delete()

    # ۴. افزودن استانداردهای ایستگاه ABS
    spec1 = models.ModelSpecification(
        model_id=model.id,
        station_code="ABS",
        item_key="thickness",
        item_label="ضخامت ورق بدنه",
        data_type=models.DataType.NUMERIC,
        target_value=1.5,
        min_value=1.2,
        max_value=1.8,
        unit="mm"
    )

    spec2 = models.ModelSpecification(
        model_id=model.id,
        station_code="ABS",
        item_key="scratch",
        item_label="بررسی خط و خش بدنه",
        data_type=models.DataType.BOOLEAN,
        expected_text="PASS"
    )

    db.add_all([spec1, spec2])
    db.commit()
    print("داده‌های اولیه با موفقیت بر اساس ساختار دقیق models.py ثبت شدند!")

except Exception as e:
    db.rollback()
    print(f"خطا در ثبت داده‌ها: {e}")
finally:
    db.close()