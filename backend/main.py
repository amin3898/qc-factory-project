import io
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session
import pandas as pd
import crud, models, schemas
from database import SessionLocal, engine

models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="QC Factory API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Endpointهای مربوط به مدل‌ها و استانداردهای مهندسی ---

@app.post("/api/models/", response_model=schemas.ModelOut)
@app.post("/api/models", response_model=schemas.ModelOut)
def create_model(model: schemas.ModelCreate, db: Session = Depends(get_db)):
    db_model = crud.get_model_by_code(db, code=model.code)
    if db_model:
        raise HTTPException(status_code=400, detail="این کد مدل قبلاً ثبت شده است")
    return crud.create_model_with_specs(db=db, model=model)

@app.get("/api/models-list/")
@app.get("/api/models-list")
@app.get("/api/models/")
@app.get("/api/models")
def get_models_list(db: Session = Depends(get_db)):
    return crud.get_all_models_with_stations(db)

@app.get("/api/models/{model_code}/specs/{station_code}")
def get_specs(model_code: str, station_code: str, db: Session = Depends(get_db)):
    specs = crud.get_specs_by_model_and_station(db, model_code=model_code, station_code=station_code)
    if not specs:
        raise HTTPException(status_code=404, detail="استانداردی برای این ایستگاه یافت نشد")
    return specs

@app.post("/api/station-specs")
@app.post("/api/station-specs/")
def save_station_specs(payload: dict, db: Session = Depends(get_db)):
    model_code = payload.get("model_code")
    station_code = payload.get("station_code")
    specifications = payload.get("specifications", [])
    
    if not model_code or not station_code:
        raise HTTPException(status_code=400, detail="کد مدل و ایستگاه الزامی است")
        
    db_model = crud.get_model_by_code(db, code=model_code)
    if not db_model:
        db_model = models.ProductModel(code=model_code, title=model_code)
        db.add(db_model)
        db.commit()
        db.refresh(db_model)
        
    db.query(models.ModelSpecification).filter(
        models.ModelSpecification.model_id == db_model.id,
        models.ModelSpecification.station_code == station_code
    ).delete()
    
    for spec in specifications:
        db_spec = models.ModelSpecification(
            model_id=db_model.id,
            station_code=station_code,
            item_key=spec.get("item_key"),
            item_label=spec.get("item_label"),
            data_type=spec.get("data_type", "numeric"),
            target_value=spec.get("target_value"),
            min_value=spec.get("min_value"),
            max_value=spec.get("max_value"),
            unit=spec.get("unit")
        )
        db.add(db_spec)
        
    db.commit()
    return {"message": "استانداردهای ایستگاه با موفقیت ذخیره شد"}

@app.put("/api/models/{model_code}")
def update_model_specs(model_code: str, model: schemas.ModelCreate, db: Session = Depends(get_db)):
    db_model = crud.get_model_by_code(db, code=model_code)
    if not db_model:
        raise HTTPException(status_code=404, detail="مدل یافت نشد")
    
    if model.specifications:
        target_station = model.specifications[0].station_code
        
        db.query(models.ModelSpecification).filter(
            models.ModelSpecification.model_id == db_model.id,
            models.ModelSpecification.station_code == target_station
        ).delete()
        
        for spec in model.specifications:
            db_spec = models.ModelSpecification(
                model_id=db_model.id,
                station_code=spec.station_code,
                item_key=spec.item_key,
                item_label=spec.item_label,
                data_type=spec.data_type,
                target_value=spec.target_value,
                min_value=spec.min_value,
                max_value=spec.max_value,
                unit=spec.unit
            )
            db.add(db_spec)
        
        db.commit()
    return {"message": "استانداردهای ایستگاه با موفقیت ثبت/به‌روزرسانی شد"}

@app.delete("/api/models/{model_code}/stations/{station_code}")
def delete_model_station(model_code: str, station_code: str, db: Session = Depends(get_db)):
    db_model = crud.get_model_by_code(db, code=model_code)
    if not db_model:
        raise HTTPException(status_code=404, detail="مدل یافت نشد")
    
    deleted_count = db.query(models.ModelSpecification).filter(
        models.ModelSpecification.model_id == db_model.id,
        models.ModelSpecification.station_code == station_code
    ).delete()
    
    db.commit()
    if deleted_count == 0:
        raise HTTPException(status_code=404, detail="ایستگاهی با این نام یافت نشد")
        
    return {"message": f"ایستگاه {station_code} با موفقیت حذف شد"}

@app.delete("/api/models/{model_code}")
def delete_entire_model(model_code: str, db: Session = Depends(get_db)):
    db_model = crud.get_model_by_code(db, code=model_code)
    if not db_model:
        raise HTTPException(status_code=404, detail="مدل یافت نشد")
    
    # حذف مشخصات وابسته برای جلوگیری از خطای کلید خارجی
    db.query(models.ModelSpecification).filter(
        models.ModelSpecification.model_id == db_model.id
    ).delete()
    
    db.delete(db_model)
    db.commit()
    return {"message": f"مدل {model_code} با موفقیت حذف شد"}

# --- Endpointهای ثبت و گزارش‌گیری بازرسی ---

@app.post("/api/inspections/")
@app.post("/api/inspections")
def create_inspection(inspection: schemas.InspectionHeaderCreate, db: Session = Depends(get_db)):
    return crud.create_inspection_entry(db=db, inspection=inspection)

@app.get("/api/inspections/report")
def get_inspection_reports(overall_status: str = None, target_date: str = None, db: Session = Depends(get_db)):
    return crud.get_inspection_reports(db, overall_status=overall_status, target_date=target_date)

@app.delete("/api/inspections/{inspection_id}")
def delete_inspection_endpoint(inspection_id: int, db: Session = Depends(get_db)):
    success = crud.delete_inspection(db, inspection_id=inspection_id)
    if not success:
        raise HTTPException(status_code=404, detail="گزارش بازرسی یافت نشد")
    return {"message": "گزارش با موفقیت حذف شد"}

@app.put("/api/inspections/{inspection_id}")
def update_inspection_endpoint(
    inspection_id: int, 
    auditor_name: str = None, 
    shift: str = None, 
    db: Session = Depends(get_db)
):
    updated = crud.update_inspection(db, inspection_id=inspection_id, auditor_name=auditor_name, shift=shift)
    if not updated:
        raise HTTPException(status_code=404, detail="گزارش بازرسی یافت نشد")
    return updated

@app.get("/api/inspections/export/excel")
def export_inspections_excel(target_date: str = None, db: Session = Depends(get_db)):
    reports = crud.get_inspection_reports(db, target_date=target_date)
    
    flat_data = []
    for r in reports:
        for d in r["details"]:
            flat_data.append({
                "کد گزارش": r["id"],
                "تاریخ بازرسی": r["inspection_date"],
                "کد مدل": r["model_code"],
                "ایستگاه": r["station_code"],
                "نام بازرس": r["auditor_name"],
                "شیفت": r["shift"],
                "وضعیت کلی ایستگاه": r["overall_status"],
                "عنوان آیتم": d["item_label"],
                "مقدار عددی": d["measured_value"],
                "وضعیت ظاهری": d["visual_status"],
                "نتیجه آیتم": d["status"]
            })
            
    df = pd.DataFrame(flat_data)
    stream = io.BytesIO()
    with pd.ExcelWriter(stream, engine='openpyxl') as writer:
        df.to_excel(writer, index=False, sheet_name='گزارش بازرسی QC')
        
    stream.seek(0)
    headers = {
        'Content-Disposition': 'attachment; filename="QC_Inspection_Report.xlsx"'
    }
    return StreamingResponse(stream, headers=headers, media_type='application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')

@app.get("/api/dashboard/stats")
def get_dashboard_stats(db: Session = Depends(get_db)):
    inspections = db.query(models.Inspection).all()
    total_count = len(inspections)
    ok_count = sum(1 for i in inspections if i.overall_status == "OK")
    ng_count = total_count - ok_count
    
    ftt_rate = round((ok_count / total_count * 100), 1) if total_count > 0 else 100.0

    defect_counts = {}
    station_stats = {}

    details = db.query(models.InspectionDetail).all()
    for d in details:
        if d.status == "NG":
            label = d.item_label or "نا مشخص"
            defect_counts[label] = defect_counts.get(label, 0) + 1

    top_defects = sorted([{"defect": k, "count": v} for k, v in defect_counts.items()], key=lambda x: x["count"], reverse=True)[:5]

    for i in inspections:
        st = i.station_code
        if st not in station_stats:
            station_stats[st] = {"station": st, "total": 0, "ok": 0, "ng": 0}
        station_stats[st]["total"] += 1
        if i.overall_status == "OK":
            station_stats[st]["ok"] += 1
        else:
            station_stats[st]["ng"] += 1

    return {
        "total_inspections": total_count,
        "ok_count": ok_count,
        "ng_count": ng_count,
        "ftt_rate": ftt_rate,
        "top_defects": top_defects,
        "station_stats": list(station_stats.values())
    }