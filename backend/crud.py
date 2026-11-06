from sqlalchemy.orm import Session
import models, schemas

def get_model_by_code(db: Session, code: str):
    return db.query(models.ProductModel).filter(models.ProductModel.code == code).first()

def create_model_with_specs(db: Session, model: schemas.ModelCreate):
    db_model = models.ProductModel(
        code=model.code,
        title=model.title,
        description=model.description
    )
    db.add(db_model)
    db.commit()
    db.refresh(db_model)

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
    return db_model

def get_all_models_with_stations(db: Session):
    models_list = db.query(models.ProductModel).all()
    result = []
    for m in models_list:
        stations = db.query(models.ModelSpecification.station_code).filter(
            models.ModelSpecification.model_id == m.id
        ).distinct().all()
        station_codes = [s[0] for s in stations]
        result.append({
            "code": m.code,
            "title": m.title,
            "stations": station_codes
        })
    return result

def get_specs_by_model_and_station(db: Session, model_code: str, station_code: str):
    model = get_model_by_code(db, code=model_code)
    if not model:
        return []
    return db.query(models.ModelSpecification).filter(
        models.ModelSpecification.model_id == model.id,
        models.ModelSpecification.station_code == station_code
    ).all()

def create_inspection_entry(db: Session, inspection: schemas.InspectionHeaderCreate):
    overall_status = "OK"
    specs = get_specs_by_model_and_station(db, inspection.model_code, inspection.station_code)
    specs_dict = {s.item_key: s for s in specs}
    details_to_create = []

    for item in inspection.details:
        item_status = "OK"
        spec = specs_dict.get(item.item_key)

        if spec:
            if spec.data_type == "numeric" and item.measured_value is not None:
                if spec.min_value is not None and item.measured_value < spec.min_value:
                    item_status = "NG"
                if spec.max_value is not None and item.measured_value > spec.max_value:
                    item_status = "NG"
            elif spec.data_type == "boolean":
                if item.visual_status == "NG":
                    item_status = "NG"

        if item_status == "NG":
            overall_status = "NG"

        details_to_create.append({
            "item_key": item.item_key,
            "item_label": item.item_label,
            "measured_value": item.measured_value,
            "visual_status": item.visual_status,
            "status": item_status,
            "defect_type": item.defect_type
        })

    model = get_model_by_code(db, inspection.model_code)
    if not model:
        raise Exception("مدل یافت نشد")

    db_header = models.Inspection(
        model_id=model.id,
        station_code=inspection.station_code,
        auditor_name=inspection.auditor_name,
        shift=inspection.shift,
        inspection_date=inspection.inspection_date,
        overall_status=overall_status
    )
    db.add(db_header)
    db.commit()
    db.refresh(db_header)

    for d in details_to_create:
        db_detail = models.InspectionDetail(
            inspection_id=db_header.id,
            **d
        )
        db.add(db_detail)

    db.commit()
    return {"header_id": db_header.id, "overall_status": overall_status}

def get_inspection_reports(db: Session, overall_status: str = None, target_date: str = None):
    query = db.query(models.Inspection)
    
    if overall_status and overall_status != "ALL":
        query = query.filter(models.Inspection.overall_status == overall_status)
        
    if target_date and target_date.strip() != "":
        query = query.filter(models.Inspection.inspection_date == target_date)
    
    headers = query.order_by(models.Inspection.id.desc()).all()
    
    result = []
    for h in headers:
        details = db.query(models.InspectionDetail).filter(models.InspectionDetail.inspection_id == h.id).all()
        result.append({
            "id": h.id,
            "model_code": h.product_model.code if h.product_model else "",
            "station_code": h.station_code,
            "auditor_name": h.auditor_name,
            "shift": h.shift,
            "inspection_date": h.inspection_date or (h.created_at.strftime("%Y-%m-%d") if h.created_at else ""),
            "overall_status": h.overall_status,
            "created_at": h.created_at.strftime("%Y-%m-%d %H:%M") if h.created_at else "",
            "details": [{
                "item_key": d.item_key,
                "item_label": d.item_label,
                "measured_value": d.measured_value,
                "visual_status": d.visual_status,
                "status": d.status,
                "defect_type": d.defect_type
            } for d in details]
        })
    return result

def update_inspection(db: Session, inspection_id: int, auditor_name: str = None, shift: str = None):
    db_inspection = db.query(models.Inspection).filter(models.Inspection.id == inspection_id).first()
    if db_inspection:
        if auditor_name:
            db_inspection.auditor_name = auditor_name
        if shift:
            db_inspection.shift = shift
        db.commit()
        db.refresh(db_inspection)
    return db_inspection

def delete_inspection(db: Session, inspection_id: int):
    db_inspection = db.query(models.Inspection).filter(models.Inspection.id == inspection_id).first()
    if db_inspection:
        db.query(models.InspectionDetail).filter(models.InspectionDetail.inspection_id == inspection_id).delete()
        db.delete(db_inspection)
        db.commit()
        return True
    return False