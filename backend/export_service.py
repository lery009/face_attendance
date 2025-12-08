"""
Export Service - Generate attendance reports in CSV, Excel, and PDF formats
"""
import pandas as pd
from io import BytesIO
from datetime import datetime
from typing import List, Dict
from reportlab.lib import colors
from reportlab.lib.pagesizes import letter, A4
from reportlab.platypus import SimpleDocTemplate, Table, TableStyle, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib.enums import TA_CENTER, TA_LEFT


class ExportService:
    """Service for exporting attendance data in various formats"""

    @staticmethod
    def prepare_attendance_data(attendance_records: List[Dict]) -> pd.DataFrame:
        """Convert attendance records to pandas DataFrame"""
        if not attendance_records:
            return pd.DataFrame()

        # Convert to DataFrame
        df = pd.DataFrame(attendance_records)

        # Format datetime columns
        if 'timestamp' in df.columns:
            df['Date'] = pd.to_datetime(df['timestamp']).dt.strftime('%Y-%m-%d')
            df['Time'] = pd.to_datetime(df['timestamp']).dt.strftime('%I:%M:%S %p')

        # Select and rename columns
        column_mapping = {
            'employee_id': 'Employee ID',
            'Date': 'Date',
            'Time': 'Time',
            'confidence': 'Confidence',
            'status': 'Status',
            'notes': 'Notes',
            'method': 'Method'
        }

        # Keep only relevant columns
        available_columns = [col for col in column_mapping.keys() if col in df.columns]
        df = df[available_columns]
        df = df.rename(columns=column_mapping)

        return df

    @staticmethod
    def export_to_csv(attendance_records: List[Dict]) -> BytesIO:
        """Export attendance data to CSV format"""
        df = ExportService.prepare_attendance_data(attendance_records)

        buffer = BytesIO()
        df.to_csv(buffer, index=False, encoding='utf-8')
        buffer.seek(0)
        return buffer

    @staticmethod
    def export_to_excel(attendance_records: List[Dict]) -> BytesIO:
        """Export attendance data to Excel format with formatting"""
        df = ExportService.prepare_attendance_data(attendance_records)

        buffer = BytesIO()

        with pd.ExcelWriter(buffer, engine='openpyxl') as writer:
            df.to_excel(writer, sheet_name='Attendance Report', index=False)

            # Get workbook and worksheet
            workbook = writer.book
            worksheet = writer.sheets['Attendance Report']

            # Format header row
            for cell in worksheet[1]:
                cell.font = cell.font.copy(bold=True, size=12)
                cell.fill = cell.fill.copy(fgColor='4472C4', patternType='solid')
                cell.font = cell.font.copy(color='FFFFFF')

            # Auto-adjust column widths
            for column in worksheet.columns:
                max_length = 0
                column_letter = column[0].column_letter
                for cell in column:
                    try:
                        if len(str(cell.value)) > max_length:
                            max_length = len(str(cell.value))
                    except:
                        pass
                adjusted_width = min(max_length + 2, 50)
                worksheet.column_dimensions[column_letter].width = adjusted_width

            # Apply status color coding
            if 'Status' in df.columns:
                status_col_idx = df.columns.get_loc('Status') + 1
                for row_idx in range(2, len(df) + 2):
                    cell = worksheet.cell(row=row_idx, column=status_col_idx)
                    status = str(cell.value).lower()

                    if status == 'on_time':
                        cell.fill = cell.fill.copy(fgColor='C6EFCE', patternType='solid')
                    elif status == 'late':
                        cell.fill = cell.fill.copy(fgColor='FFEB9C', patternType='solid')
                    elif status == 'half_day':
                        cell.fill = cell.fill.copy(fgColor='FFC7CE', patternType='solid')

        buffer.seek(0)
        return buffer

    @staticmethod
    def export_to_pdf(attendance_records: List[Dict], title: str = "Attendance Report") -> BytesIO:
        """Export attendance data to PDF format"""
        df = ExportService.prepare_attendance_data(attendance_records)

        buffer = BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4)
        elements = []

        # Styles
        styles = getSampleStyleSheet()
        title_style = ParagraphStyle(
            'CustomTitle',
            parent=styles['Heading1'],
            fontSize=24,
            textColor=colors.HexColor('#1e3a8a'),
            spaceAfter=30,
            alignment=TA_CENTER
        )

        # Title
        elements.append(Paragraph(title, title_style))
        elements.append(Spacer(1, 0.2*inch))

        # Metadata
        metadata_style = styles['Normal']
        elements.append(Paragraph(f"Generated: {datetime.now().strftime('%B %d, %Y %I:%M %p')}", metadata_style))
        elements.append(Paragraph(f"Total Records: {len(df)}", metadata_style))
        elements.append(Spacer(1, 0.3*inch))

        # Table data
        if not df.empty:
            # Prepare table data
            table_data = [df.columns.tolist()] + df.values.tolist()

            # Create table
            table = Table(table_data)

            # Table style
            table_style = TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#4472C4')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 10),
                ('BOTTOMPADDING', (0, 0), (-1, 0), 12),
                ('BACKGROUND', (0, 1), (-1, -1), colors.beige),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('FONTNAME', (0, 1), (-1, -1), 'Helvetica'),
                ('FONTSIZE', (0, 1), (-1, -1), 8),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.lightgrey]),
            ])

            # Apply status-based coloring
            if 'Status' in df.columns:
                status_col_idx = df.columns.get_loc('Status')
                for row_idx, status in enumerate(df['Status'], start=1):
                    if status == 'on_time':
                        table_style.add('BACKGROUND', (status_col_idx, row_idx), (status_col_idx, row_idx), colors.lightgreen)
                    elif status == 'late':
                        table_style.add('BACKGROUND', (status_col_idx, row_idx), (status_col_idx, row_idx), colors.yellow)
                    elif status == 'half_day':
                        table_style.add('BACKGROUND', (status_col_idx, row_idx), (status_col_idx, row_idx), colors.lightcoral)

            table.setStyle(table_style)
            elements.append(table)
        else:
            elements.append(Paragraph("No attendance records found.", styles['Normal']))

        # Build PDF
        doc.build(elements)
        buffer.seek(0)
        return buffer


class EventExportService:
    """Service for exporting event attendance reports"""

    @staticmethod
    def export_event_attendance(event_data: Dict, participants: List[Dict], format: str = 'pdf') -> BytesIO:
        """Export event attendance in specified format"""

        if format == 'csv':
            return EventExportService._export_event_csv(event_data, participants)
        elif format == 'excel':
            return EventExportService._export_event_excel(event_data, participants)
        else:  # pdf
            return EventExportService._export_event_pdf(event_data, participants)

    @staticmethod
    def _export_event_csv(event_data: Dict, participants: List[Dict]) -> BytesIO:
        """Export event attendance to CSV"""
        df = pd.DataFrame(participants)

        buffer = BytesIO()
        # Add event header
        buffer.write(f"Event: {event_data.get('name', 'N/A')}\n".encode())
        buffer.write(f"Date: {event_data.get('event_date', 'N/A')}\n".encode())
        buffer.write(f"Location: {event_data.get('location', 'N/A')}\n\n".encode())

        # Add participant data
        df.to_csv(buffer, index=False, mode='a')
        buffer.seek(0)
        return buffer

    @staticmethod
    def _export_event_excel(event_data: Dict, participants: List[Dict]) -> BytesIO:
        """Export event attendance to Excel with formatting"""
        df = pd.DataFrame(participants)

        buffer = BytesIO()
        with pd.ExcelWriter(buffer, engine='openpyxl') as writer:
            # Event info sheet
            event_info = pd.DataFrame([
                ['Event Name', event_data.get('name', 'N/A')],
                ['Date', str(event_data.get('event_date', 'N/A'))],
                ['Location', event_data.get('location', 'N/A')],
                ['Status', event_data.get('status', 'N/A')],
                ['Total Participants', len(participants)]
            ])
            event_info.to_excel(writer, sheet_name='Event Info', index=False, header=False)

            # Participants sheet
            df.to_excel(writer, sheet_name='Participants', index=False)

            # Format participants sheet
            workbook = writer.book
            worksheet = writer.sheets['Participants']

            for cell in worksheet[1]:
                cell.font = cell.font.copy(bold=True, size=12)
                cell.fill = cell.fill.copy(fgColor='4472C4', patternType='solid')
                cell.font = cell.font.copy(color='FFFFFF')

        buffer.seek(0)
        return buffer

    @staticmethod
    def _export_event_pdf(event_data: Dict, participants: List[Dict]) -> BytesIO:
        """Export event attendance to PDF certificate"""
        buffer = BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=letter)
        elements = []

        styles = getSampleStyleSheet()
        title_style = ParagraphStyle(
            'EventTitle',
            parent=styles['Heading1'],
            fontSize=20,
            textColor=colors.HexColor('#1e3a8a'),
            spaceAfter=20,
            alignment=TA_CENTER
        )

        # Event title
        elements.append(Paragraph(f"Event Attendance Report", title_style))
        elements.append(Spacer(1, 0.2*inch))

        # Event details
        elements.append(Paragraph(f"<b>Event:</b> {event_data.get('name', 'N/A')}", styles['Normal']))
        elements.append(Paragraph(f"<b>Date:</b> {event_data.get('event_date', 'N/A')}", styles['Normal']))
        elements.append(Paragraph(f"<b>Location:</b> {event_data.get('location', 'N/A')}", styles['Normal']))
        elements.append(Paragraph(f"<b>Total Participants:</b> {len(participants)}", styles['Normal']))
        elements.append(Spacer(1, 0.3*inch))

        # Participants table
        if participants:
            df = pd.DataFrame(participants)
            table_data = [df.columns.tolist()] + df.values.tolist()

            table = Table(table_data)
            table.setStyle(TableStyle([
                ('BACKGROUND', (0, 0), (-1, 0), colors.HexColor('#4472C4')),
                ('TEXTCOLOR', (0, 0), (-1, 0), colors.whitesmoke),
                ('ALIGN', (0, 0), (-1, -1), 'CENTER'),
                ('FONTNAME', (0, 0), (-1, 0), 'Helvetica-Bold'),
                ('FONTSIZE', (0, 0), (-1, 0), 10),
                ('GRID', (0, 0), (-1, -1), 1, colors.black),
                ('ROWBACKGROUNDS', (0, 1), (-1, -1), [colors.white, colors.lightgrey]),
            ]))

            elements.append(table)

        doc.build(elements)
        buffer.seek(0)
        return buffer
