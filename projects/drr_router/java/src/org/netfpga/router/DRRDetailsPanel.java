/*
 * DRRDetailsPanel.java
 *
 * Created on May 31, 2008, 9:27 PM
 */

package org.netfpga.router;

import java.awt.event.ActionEvent;
import java.awt.event.ActionListener;

import org.netfpga.backend.NFDevice;
import org.netfpga.backend.NFDrrDeviceConsts;
import org.netfpga.backend.RegTableModel;

import javax.swing.AbstractButton;
import javax.swing.event.TableModelEvent;
import javax.swing.event.TableModelListener;
import javax.swing.Timer;

/**
 *
 * @author  mazurek
 */
public class DRRDetailsPanel extends javax.swing.JPanel {
    
    private static final int numDrrQueues = 5;
    
    private RegSliderGroupControl quantumSliderCtrl;
    private RegSliderGroupControl slowFactorSliderCtrl;
    private RegSliderGroupControl queue0WeightSliderCtrl;
    private RegSliderGroupControl queue1WeightSliderCtrl;
    private RegSliderGroupControl queue2WeightSliderCtrl;
    private RegSliderGroupControl queue3WeightSliderCtrl;
    private RegSliderGroupControl queue4WeightSliderCtrl;
    
    private StatsRegTableModel drrStatsRegTableModel;
    private RegTableModel regTableModel;
    
    private StatsCollection[] statsCollection;
    
    private NFDevice nf2;

    private Timer timer;
    private ActionListener timerActionListener;

    private AbstractMainFrame mainFrame;

    /** Creates new form DRRDetailsPanel */
    public DRRDetailsPanel(NFDevice nf2, Timer timer, AbstractMainFrame mainFrame) {
        
        this.nf2 = nf2;
        this.timer = timer;
        this.mainFrame = mainFrame;
        
        initComponents();
        
        /* create controller for the quantum slider */
        quantumSliderCtrl = new RegSliderGroupControl(nf2, this.quantumSlider,
                this.quantumSliderValueLabel,
                NFDrrDeviceConsts.DRR_OQ_QUANTUM_REG);
        quantumSliderCtrl.setVt(new ValueTransformer(){

            public int toRegisterValue(int val) {
                
                RegTableModel regTable = queue0WeightSliderCtrl.getRegTableModel();
                int weight = queue0WeightSliderCtrl.getSlider().getValue();
                System.out.println("Setting credit reg to "+(int)(weight * val / 10));

                regTable.setValueAt((int)(weight * val), 0, RegTableModel.VALUE_COL);

                return val;
            }

            public int toSliderValue(int val) {
                return val;
            }

            public String toLabelStringFromComponent(int val) {
                return ""+val+" bytes";
            }

            public String toLabelStringFromReg(int val) {
                return ""+val+" bytes";
            }

        });
        
        /* create controller for the quantum slider */
        slowFactorSliderCtrl = new RegSliderGroupControl(nf2, this.slowFactorSlider,
                this.slowFactorSliderValueLabel,
                NFDrrDeviceConsts.DRR_OQ_SLOW_FACTOR_REG);
        slowFactorSliderCtrl.setVt(new ValueTransformer(){

            public int toRegisterValue(int val) {
                /* change number in 64-bit words */
                return val;
            }

            public int toSliderValue(int val) {
                return val;
            }

            public String toLabelStringFromComponent(int val) {
                return ""+val;
            }

            public String toLabelStringFromReg(int val) {
                return ""+val;
            }

        });
        
        /* create controller for the weight sliders */
        ValueTransformer weightValueTransformer = new ValueTransformer(){

            public int toRegisterValue(int val) {
                RegTableModel regTable = queue0WeightSliderCtrl.getRegTableModel();
                return ((Integer)regTable.getValueAt(1, RegTableModel.VALUE_COL)) * val / 10;
            }

            public int toSliderValue(int val) {
                /* RegTableModel regTable = queue0WeightSliderCtrl.getRegTableModel(); */
                return val;
                /* return 10 * val / ((Integer)regTable.getValueAt(1, RegTableModel.VALUE_COL)); */
            }

            public String toLabelStringFromComponent(int val) {
                return ""+val/10f;
            }

            public String toLabelStringFromReg(int val) {
                return ""+val/10f;
            }

        };
        
        queue0WeightSliderCtrl = new RegSliderGroupControl(nf2, this.queue0DRRWeightSlider,
                this.queue0DRRWeightSliderValue,
                NFDrrDeviceConsts.DRR_OQ_QUEUE0_CREDIT_REG,NFDrrDeviceConsts.DRR_OQ_QUANTUM_REG,
                weightValueTransformer);
        
        queue1WeightSliderCtrl = new RegSliderGroupControl(nf2, this.queue1DRRWeightSlider,
                this.queue1DRRWeightSliderValue,
                NFDrrDeviceConsts.DRR_OQ_QUEUE1_CREDIT_REG,NFDrrDeviceConsts.DRR_OQ_QUANTUM_REG,
                weightValueTransformer);
        
        queue2WeightSliderCtrl = new RegSliderGroupControl(nf2, this.queue2DRRWeightSlider,
                this.queue2DRRWeightSliderValue,
                NFDrrDeviceConsts.DRR_OQ_QUEUE2_CREDIT_REG,NFDrrDeviceConsts.DRR_OQ_QUANTUM_REG,
                weightValueTransformer);        
        
        queue3WeightSliderCtrl = new RegSliderGroupControl(nf2, this.queue3DRRWeightSlider,
                this.queue3DRRWeightSliderValue,
                NFDrrDeviceConsts.DRR_OQ_QUEUE3_CREDIT_REG,NFDrrDeviceConsts.DRR_OQ_QUANTUM_REG,
                weightValueTransformer);
        
        queue4WeightSliderCtrl = new RegSliderGroupControl(nf2, this.queue1DRRWeightSlider3,
                this.queue4DRRWeightSliderValue,
                NFDrrDeviceConsts.DRR_OQ_QUEUE4_CREDIT_REG,NFDrrDeviceConsts.DRR_OQ_QUANTUM_REG,
                weightValueTransformer);
        
        setupDRRStatsTable(nf2);
        
        /* Create a StatsCollection for updating labels. */
        statsCollection = new StatsCollection[numDrrQueues * 3];
        statsCollection[0] = new StatsCollection(this.queue0ReceivedValueLabel, null);
        statsCollection[1] = new StatsCollection(this.queue0DroppedValueLabel, null);
        statsCollection[2] = new StatsCollection(this.queue0OccupancyValueLabel, null);
        statsCollection[2].setLabelMultiplier(8); // 64-bit words
        statsCollection[3] = new StatsCollection(this.queue1ReceivedValueLabel, null);
        statsCollection[4] = new StatsCollection(this.queue1DroppedValueLabel, null);
        statsCollection[5] = new StatsCollection(this.queue1OccupancyValueLabel, null);
        statsCollection[5].setLabelMultiplier(8); // 64-bit words
        statsCollection[6] = new StatsCollection(this.queue2ReceivedValueLabel, null);
        statsCollection[7] = new StatsCollection(this.queue2DroppedValueLabel, null);
        statsCollection[8] = new StatsCollection(this.queue2OccupancyValueLabel, null);
        statsCollection[8].setLabelMultiplier(8); // 64-bit words
        statsCollection[9] = new StatsCollection(this.queue3ReceivedValueLabel, null);
        statsCollection[10] = new StatsCollection(this.queue3DroppedValueLabel, null);
        statsCollection[11] = new StatsCollection(this.queue3OccupancyValueLabel, null);
        statsCollection[11].setLabelMultiplier(8); // 64-bit words
        statsCollection[12] = new StatsCollection(this.queue4ReceivedValueLabel, null);
        statsCollection[13] = new StatsCollection(this.queue4DroppedValueLabel, null);
        statsCollection[14] = new StatsCollection(this.queue4OccupancyValueLabel, null);
        statsCollection[14].setLabelMultiplier(8); // 64-bit words
        
        long[] addresses = new long[numDrrQueues * 3];

        addresses[0] = NFDrrDeviceConsts.DRR_QCLASS_Q0_NUM_PKTS_REG;
        addresses[1] = NFDrrDeviceConsts.DRR_OQ_QUEUE0_NUM_DROP_REG;
        addresses[2] = NFDrrDeviceConsts.DRR_OQ_QUEUE0_OCCUPANCY_REG;
        addresses[3] = NFDrrDeviceConsts.DRR_QCLASS_Q1_NUM_PKTS_REG;
        addresses[4] = NFDrrDeviceConsts.DRR_OQ_QUEUE1_NUM_DROP_REG;
        addresses[5] = NFDrrDeviceConsts.DRR_OQ_QUEUE1_OCCUPANCY_REG;
        addresses[6] = NFDrrDeviceConsts.DRR_QCLASS_Q2_NUM_PKTS_REG;
        addresses[7] = NFDrrDeviceConsts.DRR_OQ_QUEUE2_NUM_DROP_REG;
        addresses[8] = NFDrrDeviceConsts.DRR_OQ_QUEUE2_OCCUPANCY_REG;
        addresses[9] = NFDrrDeviceConsts.DRR_QCLASS_Q3_NUM_PKTS_REG;
        addresses[10] = NFDrrDeviceConsts.DRR_OQ_QUEUE3_NUM_DROP_REG;
        addresses[11] = NFDrrDeviceConsts.DRR_OQ_QUEUE3_OCCUPANCY_REG;
        addresses[12] = NFDrrDeviceConsts.DRR_QCLASS_Q4_NUM_PKTS_REG;
        addresses[13] = NFDrrDeviceConsts.DRR_OQ_QUEUE4_NUM_DROP_REG;
        addresses[14] = NFDrrDeviceConsts.DRR_OQ_QUEUE4_OCCUPANCY_REG;
        
        regTableModel = new RegTableModel(nf2, addresses);
        
        /* Add listener to changes in the register values */
        regTableModel.addTableModelListener(new TableModelListener() {
            public void tableChanged(TableModelEvent e) {
                int firstRow = e.getFirstRow();
                int lastRow = e.getLastRow();
                for(int i=firstRow; i<=lastRow; i++){
                    if(i!=TableModelEvent.HEADER_ROW){
                        statsCollection[i].update(regTableModel.getRegisterAt(i).getValue());
                    }
                }
            }
        });
              
        /* add listeners to the update the tables */
        timerActionListener = new ActionListener() {
            public void actionPerformed(ActionEvent e) {
                regTableModel.updateTable();
                queue0WeightSliderCtrl.getRegTableModel().updateTable();
                quantumSliderCtrl.getRegTableModel().updateTable();
                slowFactorSliderCtrl.getRegTableModel().updateTable();
                drrStatsRegTableModel.updateTable();
            }
        };

        /* add action listener to the timer */
        this.timer.addActionListener(timerActionListener);
    }
    
    private void setupDRRStatsTable(NFDevice nf2) {
        /* add the addresses to monitor through statsRegTableModel */
        long[] aAddresses = new long[numDrrQueues * 3];

        aAddresses[0] = NFDrrDeviceConsts.DRR_QCLASS_Q0_NUM_PKTS_REG;
        aAddresses[1] = NFDrrDeviceConsts.DRR_OQ_QUEUE0_NUM_DROP_REG;
        aAddresses[2] = NFDrrDeviceConsts.DRR_OQ_QUEUE0_OCCUPANCY_REG;
        aAddresses[3] = NFDrrDeviceConsts.DRR_QCLASS_Q1_NUM_PKTS_REG;
        aAddresses[4] = NFDrrDeviceConsts.DRR_OQ_QUEUE1_NUM_DROP_REG;
        aAddresses[5] = NFDrrDeviceConsts.DRR_OQ_QUEUE1_OCCUPANCY_REG;
        aAddresses[6] = NFDrrDeviceConsts.DRR_QCLASS_Q2_NUM_PKTS_REG;
        aAddresses[7] = NFDrrDeviceConsts.DRR_OQ_QUEUE2_NUM_DROP_REG;
        aAddresses[8] = NFDrrDeviceConsts.DRR_OQ_QUEUE2_OCCUPANCY_REG;
        aAddresses[9] = NFDrrDeviceConsts.DRR_QCLASS_Q3_NUM_PKTS_REG;
        aAddresses[10] = NFDrrDeviceConsts.DRR_OQ_QUEUE3_NUM_DROP_REG;
        aAddresses[11] = NFDrrDeviceConsts.DRR_OQ_QUEUE3_OCCUPANCY_REG;
        aAddresses[12] = NFDrrDeviceConsts.DRR_QCLASS_Q4_NUM_PKTS_REG;
        aAddresses[13] = NFDrrDeviceConsts.DRR_OQ_QUEUE4_NUM_DROP_REG;
        aAddresses[14] = NFDrrDeviceConsts.DRR_OQ_QUEUE4_OCCUPANCY_REG;        

        String[] descriptions = new String[numDrrQueues * 3];
        descriptions[0] = "Total packets received";
        descriptions[1] = "Total packets dropped";
        descriptions[2] = "Current queue occupancy in kB";
        descriptions[3] = "Total packets received";
        descriptions[4] = "Total packets dropped";
        descriptions[5] = "Current queue occupancy in kB";        
        descriptions[6] = "Total packets received";
        descriptions[7] = "Total packets dropped";
        descriptions[8] = "Current queue occupancy in kB";
        descriptions[9] = "Total packets received";
        descriptions[10] = "Total packets dropped";
        descriptions[11] = "Current queue occupancy in kB";
        descriptions[12] = "Total packets received";
        descriptions[13] = "Total packets dropped";
        descriptions[14] = "Current queue occupancy in kB";        

        /* create the register table model which we want to monitor */
        drrStatsRegTableModel = new StatsRegTableModel(nf2, aAddresses, descriptions);
        
        drrStatsRegTableModel.setDivider(2, 1024/8);
        drrStatsRegTableModel.setUnits(2, "kB");
        drrStatsRegTableModel.setDivider(5, 1024/8);
        drrStatsRegTableModel.setUnits(5, "kB");
        drrStatsRegTableModel.setDivider(8, 1024/8);
        drrStatsRegTableModel.setUnits(8, "kB");
        drrStatsRegTableModel.setDivider(11, 1024/8);
        drrStatsRegTableModel.setUnits(11, "kB");
        drrStatsRegTableModel.setDivider(14, 1024/8);
        drrStatsRegTableModel.setUnits(14, "kB");
        
        drrStatsRegTableModel.setGraph(0, (AreaGraphPanel)this.queue0ReceivedPanel);
        drrStatsRegTableModel.setDifferentialGraph(0, true);

        drrStatsRegTableModel.setGraph(1, (GraphPanel)this.queue0DroppedPanel);
        drrStatsRegTableModel.setDifferentialGraph(1, true);

        drrStatsRegTableModel.setGraph(2, (GraphPanel)this.queue0OccupancyPanel);
        drrStatsRegTableModel.setDifferentialGraph(2, false);
        
        drrStatsRegTableModel.setGraph(3, (AreaGraphPanel)this.queue1ReceivedPanel);
        drrStatsRegTableModel.setDifferentialGraph(3, true);

        drrStatsRegTableModel.setGraph(4, (GraphPanel)this.queue1DroppedPanel);
        drrStatsRegTableModel.setDifferentialGraph(4, true);

        drrStatsRegTableModel.setGraph(5, (GraphPanel)this.queue1OccupancyPanel);
        drrStatsRegTableModel.setDifferentialGraph(5, false);
        
        drrStatsRegTableModel.setGraph(6, (AreaGraphPanel)this.queue2ReceivedPanel);
        drrStatsRegTableModel.setDifferentialGraph(6, true);

        drrStatsRegTableModel.setGraph(7, (GraphPanel)this.queue2DroppedPanel);
        drrStatsRegTableModel.setDifferentialGraph(7, true);

        drrStatsRegTableModel.setGraph(8, (GraphPanel)this.queue2OccupancyPanel);
        drrStatsRegTableModel.setDifferentialGraph(8, false);
        
        drrStatsRegTableModel.setGraph(9, (AreaGraphPanel)this.queue3ReceivedPanel);
        drrStatsRegTableModel.setDifferentialGraph(9, true);

        drrStatsRegTableModel.setGraph(10, (GraphPanel)this.queue3DroppedPanel);
        drrStatsRegTableModel.setDifferentialGraph(10, true);

        drrStatsRegTableModel.setGraph(11, (GraphPanel)this.queue3OccupancyPanel);
        drrStatsRegTableModel.setDifferentialGraph(11, false);

        drrStatsRegTableModel.setGraph(12, (AreaGraphPanel)this.queue4ReceivedPanel);
        drrStatsRegTableModel.setDifferentialGraph(12, true);

        drrStatsRegTableModel.setGraph(13, (GraphPanel)this.queue4DroppedPanel);
        drrStatsRegTableModel.setDifferentialGraph(13, true);

        drrStatsRegTableModel.setGraph(14, (GraphPanel)this.queue4OccupancyPanel);
        drrStatsRegTableModel.setDifferentialGraph(14, false);
    }

    /** This method is called from within the constructor to
     * initialize the form.
     * WARNING: Do NOT modify this code. The content of this method is
     * always regenerated by the Form Editor.
     */
    @SuppressWarnings("unchecked")
    // <editor-fold defaultstate="collapsed" desc="Generated Code">//GEN-BEGIN:initComponents
    private void initComponents() {

        buttonGroup1 = new javax.swing.ButtonGroup();
        buttonGroup2 = new javax.swing.ButtonGroup();
        buttonGroup3 = new javax.swing.ButtonGroup();
        buttonGroup4 = new javax.swing.ButtonGroup();
        buttonGroup5 = new javax.swing.ButtonGroup();
        buttonGroup6 = new javax.swing.ButtonGroup();
        jLabel1 = new javax.swing.JLabel();
        jSeparator1 = new javax.swing.JSeparator();
        quantumSliderLabel = new javax.swing.JLabel();
        quantumSlider = new javax.swing.JSlider();
        slowFactorSliderLabel = new javax.swing.JLabel();
        slowFactorSlider = new javax.swing.JSlider();
        quantumSliderValueLabel = new javax.swing.JLabel();
        slowFactorSliderValueLabel = new javax.swing.JLabel();
        jLabel2 = new javax.swing.JLabel();
        jLabel3 = new javax.swing.JLabel();
        queue0DRRWeightSlider = new javax.swing.JSlider();
        queue0DRRWeightSliderValue = new javax.swing.JLabel();
        queue0DroppedPanel = new AreaGraphPanel("Queue #0 Packets Dropped","Packets Dropped","time","packets dropped",2000);
        queue0OccupancyPanel = new AreaGraphPanel("Queue #0 Occupancy","Queue Occupancy","time","occupancy (kB)",2000);
        queue0ReceivedPanel = new AreaGraphPanel("Queue #0 Packets Received","Packets Received","time","packets received",2000);
        queue1ReceivedPanel = new AreaGraphPanel("Queue #1 Packets Received","Packets Received","time","packets received",2000);
        queue1DroppedPanel = new AreaGraphPanel("Queue #1 Packets Dropped","Packets Dropped","time","packets dropped",2000);
        queue1OccupancyPanel = new AreaGraphPanel("Queue #1 Occupancy","Queue Occupancy","time","occupancy (kB)",2000);
        jLabel4 = new javax.swing.JLabel();
        jLabel5 = new javax.swing.JLabel();
        queue1DRRWeightSlider = new javax.swing.JSlider();
        queue1DRRWeightSliderValue = new javax.swing.JLabel();
        queue2ReceivedPanel = new AreaGraphPanel("Queue #2 Packets Received","Packets Received","time","packets received",2000);
        queue2DroppedPanel = new AreaGraphPanel("Queue #2 Packets Dropped","Packets Dropped","time","packets dropped",2000);
        queue2OccupancyPanel = new AreaGraphPanel("Queue #2 Occupancy","Queue Occupancy","time","occupancy (kB)",2000);
        queue3DroppedPanel = new AreaGraphPanel("Queue #3 Packets Dropped","Packets Dropped","time","packets dropped",2000);
        queue3ReceivedPanel = new AreaGraphPanel("Queue #3 Packets Received","Packets Received","time","packets received",2000);
        queue4OccupancyPanel = new AreaGraphPanel("Queue #4 Occupancy","Queue Occupancy","time","occupancy (kB)",2000);
        queue4DroppedPanel = new AreaGraphPanel("Queue #4 Packets Dropped","Packets Dropped","time","packets dropped",2000);
        queue4ReceivedPanel = new AreaGraphPanel("Queue #4 Packets Received","Packets Received","time","packets received",2000);
        queue3OccupancyPanel = new AreaGraphPanel("Queue #3 Occupancy","Queue Occupancy","time","occupancy (kB)",2000);
        jLabel6 = new javax.swing.JLabel();
        jLabel7 = new javax.swing.JLabel();
        queue2DRRWeightSlider = new javax.swing.JSlider();
        queue2DRRWeightSliderValue = new javax.swing.JLabel();
        jLabel8 = new javax.swing.JLabel();
        jLabel9 = new javax.swing.JLabel();
        queue3DRRWeightSlider = new javax.swing.JSlider();
        queue3DRRWeightSliderValue = new javax.swing.JLabel();
        queue4DRRWeightSliderValue = new javax.swing.JLabel();
        queue1DRRWeightSlider3 = new javax.swing.JSlider();
        jLabel10 = new javax.swing.JLabel();
        jLabel11 = new javax.swing.JLabel();
        jLabel12 = new javax.swing.JLabel();
        jLabel13 = new javax.swing.JLabel();
        jLabel14 = new javax.swing.JLabel();
        queue0ReceivedValueLabel = new javax.swing.JLabel();
        queue0DroppedValueLabel = new javax.swing.JLabel();
        queue0OccupancyValueLabel = new javax.swing.JLabel();
        jLabel15 = new javax.swing.JLabel();
        queue1OccupancyValueLabel = new javax.swing.JLabel();
        jLabel16 = new javax.swing.JLabel();
        jLabel17 = new javax.swing.JLabel();
        queue1DroppedValueLabel = new javax.swing.JLabel();
        queue1ReceivedValueLabel = new javax.swing.JLabel();
        queue2DroppedValueLabel = new javax.swing.JLabel();
        queue2ReceivedValueLabel = new javax.swing.JLabel();
        jLabel18 = new javax.swing.JLabel();
        jLabel19 = new javax.swing.JLabel();
        queue2OccupancyValueLabel = new javax.swing.JLabel();
        jLabel20 = new javax.swing.JLabel();
        queue3ReceivedValueLabel = new javax.swing.JLabel();
        jLabel21 = new javax.swing.JLabel();
        queue3DroppedValueLabel = new javax.swing.JLabel();
        jLabel22 = new javax.swing.JLabel();
        jLabel23 = new javax.swing.JLabel();
        queue3OccupancyValueLabel = new javax.swing.JLabel();
        jLabel24 = new javax.swing.JLabel();
        jLabel25 = new javax.swing.JLabel();
        queue4DroppedValueLabel = new javax.swing.JLabel();
        queue4OccupancyValueLabel = new javax.swing.JLabel();
        jLabel26 = new javax.swing.JLabel();
        queue4ReceivedValueLabel = new javax.swing.JLabel();
        resetStatsButton = new javax.swing.JButton();

        jLabel1.setFont(new java.awt.Font("Dialog", 1, 18));
        jLabel1.setText("DRR Settings");

        jSeparator1.setBorder(javax.swing.BorderFactory.createBevelBorder(javax.swing.border.BevelBorder.RAISED));

        quantumSliderLabel.setText("Quantum Size:");

        quantumSlider.setFont(new java.awt.Font("Dialog", 0, 13));
        quantumSlider.setMajorTickSpacing(500);
        quantumSlider.setMaximum(1500);
        quantumSlider.setMinimum(1);
        quantumSlider.setMinorTickSpacing(100);
        quantumSlider.setPaintTicks(true);

        slowFactorSliderLabel.setText("Slowing Factor:");

        slowFactorSlider.setMajorTickSpacing(5000);
        slowFactorSlider.setMaximum(100000);
        slowFactorSlider.setMinimum(1);
        slowFactorSlider.setMinorTickSpacing(2500);
        slowFactorSlider.setPaintTicks(true);

        quantumSliderValueLabel.setText("[Quantum Size Label]");

        slowFactorSliderValueLabel.setText("[Slow Factor Label]");

        jLabel2.setText("Queue #0:");

        jLabel3.setText("DRR Weight:");

        queue0DRRWeightSlider.setMaximum(1000);
        queue0DRRWeightSlider.setMinimum(1);

        queue0DRRWeightSliderValue.setText("[Queue 0 DRR Weight]");

        queue0DroppedPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue0DroppedPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue0DroppedPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue0DroppedPanelLayout = new javax.swing.GroupLayout(queue0DroppedPanel);
        queue0DroppedPanel.setLayout(queue0DroppedPanelLayout);
        queue0DroppedPanelLayout.setHorizontalGroup(
            queue0DroppedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue0DroppedPanelLayout.setVerticalGroup(
            queue0DroppedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue0OccupancyPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue0OccupancyPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue0OccupancyPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue0OccupancyPanelLayout = new javax.swing.GroupLayout(queue0OccupancyPanel);
        queue0OccupancyPanel.setLayout(queue0OccupancyPanelLayout);
        queue0OccupancyPanelLayout.setHorizontalGroup(
            queue0OccupancyPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue0OccupancyPanelLayout.setVerticalGroup(
            queue0OccupancyPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue0ReceivedPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue0ReceivedPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue0ReceivedPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue0ReceivedPanelLayout = new javax.swing.GroupLayout(queue0ReceivedPanel);
        queue0ReceivedPanel.setLayout(queue0ReceivedPanelLayout);
        queue0ReceivedPanelLayout.setHorizontalGroup(
            queue0ReceivedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue0ReceivedPanelLayout.setVerticalGroup(
            queue0ReceivedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue1ReceivedPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue1ReceivedPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue1ReceivedPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue1ReceivedPanelLayout = new javax.swing.GroupLayout(queue1ReceivedPanel);
        queue1ReceivedPanel.setLayout(queue1ReceivedPanelLayout);
        queue1ReceivedPanelLayout.setHorizontalGroup(
            queue1ReceivedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue1ReceivedPanelLayout.setVerticalGroup(
            queue1ReceivedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue1DroppedPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue1DroppedPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue1DroppedPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue1DroppedPanelLayout = new javax.swing.GroupLayout(queue1DroppedPanel);
        queue1DroppedPanel.setLayout(queue1DroppedPanelLayout);
        queue1DroppedPanelLayout.setHorizontalGroup(
            queue1DroppedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue1DroppedPanelLayout.setVerticalGroup(
            queue1DroppedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue1OccupancyPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue1OccupancyPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue1OccupancyPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue1OccupancyPanelLayout = new javax.swing.GroupLayout(queue1OccupancyPanel);
        queue1OccupancyPanel.setLayout(queue1OccupancyPanelLayout);
        queue1OccupancyPanelLayout.setHorizontalGroup(
            queue1OccupancyPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue1OccupancyPanelLayout.setVerticalGroup(
            queue1OccupancyPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        jLabel4.setText("Queue #1:");

        jLabel5.setText("DRR Weight:");

        queue1DRRWeightSlider.setMaximum(1000);
        queue1DRRWeightSlider.setMinimum(1);

        queue1DRRWeightSliderValue.setText("[Queue 1 DRR Weight]");

        queue2ReceivedPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue2ReceivedPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue2ReceivedPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue2ReceivedPanelLayout = new javax.swing.GroupLayout(queue2ReceivedPanel);
        queue2ReceivedPanel.setLayout(queue2ReceivedPanelLayout);
        queue2ReceivedPanelLayout.setHorizontalGroup(
            queue2ReceivedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue2ReceivedPanelLayout.setVerticalGroup(
            queue2ReceivedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue2DroppedPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue2DroppedPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue2DroppedPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue2DroppedPanelLayout = new javax.swing.GroupLayout(queue2DroppedPanel);
        queue2DroppedPanel.setLayout(queue2DroppedPanelLayout);
        queue2DroppedPanelLayout.setHorizontalGroup(
            queue2DroppedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue2DroppedPanelLayout.setVerticalGroup(
            queue2DroppedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue2OccupancyPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue2OccupancyPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue2OccupancyPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue2OccupancyPanelLayout = new javax.swing.GroupLayout(queue2OccupancyPanel);
        queue2OccupancyPanel.setLayout(queue2OccupancyPanelLayout);
        queue2OccupancyPanelLayout.setHorizontalGroup(
            queue2OccupancyPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue2OccupancyPanelLayout.setVerticalGroup(
            queue2OccupancyPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue3DroppedPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue3DroppedPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue3DroppedPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue3DroppedPanelLayout = new javax.swing.GroupLayout(queue3DroppedPanel);
        queue3DroppedPanel.setLayout(queue3DroppedPanelLayout);
        queue3DroppedPanelLayout.setHorizontalGroup(
            queue3DroppedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue3DroppedPanelLayout.setVerticalGroup(
            queue3DroppedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue3ReceivedPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue3ReceivedPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue3ReceivedPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue3ReceivedPanelLayout = new javax.swing.GroupLayout(queue3ReceivedPanel);
        queue3ReceivedPanel.setLayout(queue3ReceivedPanelLayout);
        queue3ReceivedPanelLayout.setHorizontalGroup(
            queue3ReceivedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue3ReceivedPanelLayout.setVerticalGroup(
            queue3ReceivedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue4OccupancyPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue4OccupancyPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue4OccupancyPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue4OccupancyPanelLayout = new javax.swing.GroupLayout(queue4OccupancyPanel);
        queue4OccupancyPanel.setLayout(queue4OccupancyPanelLayout);
        queue4OccupancyPanelLayout.setHorizontalGroup(
            queue4OccupancyPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue4OccupancyPanelLayout.setVerticalGroup(
            queue4OccupancyPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue4DroppedPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue4DroppedPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue4DroppedPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue4DroppedPanelLayout = new javax.swing.GroupLayout(queue4DroppedPanel);
        queue4DroppedPanel.setLayout(queue4DroppedPanelLayout);
        queue4DroppedPanelLayout.setHorizontalGroup(
            queue4DroppedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue4DroppedPanelLayout.setVerticalGroup(
            queue4DroppedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue4ReceivedPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue4ReceivedPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue4ReceivedPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue4ReceivedPanelLayout = new javax.swing.GroupLayout(queue4ReceivedPanel);
        queue4ReceivedPanel.setLayout(queue4ReceivedPanelLayout);
        queue4ReceivedPanelLayout.setHorizontalGroup(
            queue4ReceivedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue4ReceivedPanelLayout.setVerticalGroup(
            queue4ReceivedPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        queue3OccupancyPanel.setBorder(javax.swing.BorderFactory.createLineBorder(new java.awt.Color(0, 0, 0)));
        queue3OccupancyPanel.setMaximumSize(new java.awt.Dimension(32768, 32768));
        queue3OccupancyPanel.setPreferredSize(new java.awt.Dimension(200, 200));

        javax.swing.GroupLayout queue3OccupancyPanelLayout = new javax.swing.GroupLayout(queue3OccupancyPanel);
        queue3OccupancyPanel.setLayout(queue3OccupancyPanelLayout);
        queue3OccupancyPanelLayout.setHorizontalGroup(
            queue3OccupancyPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );
        queue3OccupancyPanelLayout.setVerticalGroup(
            queue3OccupancyPanelLayout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGap(0, 198, Short.MAX_VALUE)
        );

        jLabel6.setText("Queue #2:");

        jLabel7.setText("DRR Weight:");

        queue2DRRWeightSlider.setMaximum(1000);
        queue2DRRWeightSlider.setMinimum(1);

        queue2DRRWeightSliderValue.setText("[Queue 2 DRR Weight]");

        jLabel8.setText("DRR Weight:");

        jLabel9.setText("Queue #3:");

        queue3DRRWeightSlider.setMaximum(1000);
        queue3DRRWeightSlider.setMinimum(1);

        queue3DRRWeightSliderValue.setText("[Queue 3 DRR Weight]");

        queue4DRRWeightSliderValue.setText("[Queue 1 DRR Weight]");

        queue1DRRWeightSlider3.setMaximum(1000);
        queue1DRRWeightSlider3.setMinimum(1);

        jLabel10.setText("DRR Weight:");

        jLabel11.setText("Queue #4:");

        jLabel12.setText("Packets Received:");

        jLabel13.setText("Packets Dropped:");

        jLabel14.setText("Queue Occupancy (bytes):");

        queue0ReceivedValueLabel.setText("[packets]");

        queue0DroppedValueLabel.setText("[dropped]");

        queue0OccupancyValueLabel.setText("[occupancy]");

        jLabel15.setText("Queue Occupancy (bytes):");

        queue1OccupancyValueLabel.setText("[occupancy]");

        jLabel16.setText("Packets Dropped:");

        jLabel17.setText("Packets Received:");

        queue1DroppedValueLabel.setText("[dropped]");

        queue1ReceivedValueLabel.setText("[packets]");

        queue2DroppedValueLabel.setText("[dropped]");

        queue2ReceivedValueLabel.setText("[packets]");

        jLabel18.setText("Packets Received:");

        jLabel19.setText("Packets Dropped:");

        queue2OccupancyValueLabel.setText("[occupancy]");

        jLabel20.setText("Queue Occupancy (bytes):");

        queue3ReceivedValueLabel.setText("[packets]");

        jLabel21.setText("Packets Received:");

        queue3DroppedValueLabel.setText("[dropped]");

        jLabel22.setText("Packets Dropped:");

        jLabel23.setText("Queue Occupancy (bytes):");

        queue3OccupancyValueLabel.setText("[occupancy]");

        jLabel24.setText("Packets Received:");

        jLabel25.setText("Packets Dropped:");

        queue4DroppedValueLabel.setText("[dropped]");

        queue4OccupancyValueLabel.setText("[occupancy]");

        jLabel26.setText("Queue Occupancy (bytes):");

        queue4ReceivedValueLabel.setText("[packets]");

        resetStatsButton.setText("Reset Statistics");
        resetStatsButton.addActionListener(new java.awt.event.ActionListener() {
            public void actionPerformed(java.awt.event.ActionEvent evt) {
                resetStatsButtonActionPerformed(evt);
            }
        });

        javax.swing.GroupLayout layout = new javax.swing.GroupLayout(this);
        this.setLayout(layout);
        layout.setHorizontalGroup(
            layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(layout.createSequentialGroup()
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addGroup(layout.createSequentialGroup()
                        .addContainerGap()
                        .addComponent(jLabel1))
                    .addGroup(layout.createSequentialGroup()
                        .addContainerGap()
                        .addComponent(jSeparator1, javax.swing.GroupLayout.DEFAULT_SIZE, 878, Short.MAX_VALUE))
                    .addGroup(layout.createSequentialGroup()
                        .addContainerGap()
                        .addComponent(queue0ReceivedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue0DroppedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue0OccupancyPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addGroup(layout.createSequentialGroup()
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                    .addGroup(layout.createSequentialGroup()
                                        .addComponent(jLabel14)
                                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                        .addComponent(queue0OccupancyValueLabel))
                                    .addGroup(layout.createSequentialGroup()
                                        .addGap(52, 52, 52)
                                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                                            .addComponent(jLabel13)
                                            .addComponent(jLabel12))
                                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                            .addComponent(queue0DroppedValueLabel)
                                            .addComponent(queue0ReceivedValueLabel)))
                                    .addGroup(layout.createSequentialGroup()
                                        .addGap(12, 12, 12)
                                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                            .addGroup(layout.createSequentialGroup()
                                                .addGap(44, 44, 44)
                                                .addComponent(queue0DRRWeightSliderValue))
                                            .addComponent(queue0DRRWeightSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)))))
                            .addGroup(layout.createSequentialGroup()
                                .addGap(44, 44, 44)
                                .addComponent(jLabel2)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addComponent(jLabel3))))
                    .addGroup(layout.createSequentialGroup()
                        .addContainerGap()
                        .addComponent(queue1ReceivedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue1DroppedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue1OccupancyPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addGroup(layout.createSequentialGroup()
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                    .addGroup(layout.createSequentialGroup()
                                        .addGap(52, 52, 52)
                                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                                            .addComponent(jLabel16)
                                            .addComponent(jLabel17))
                                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                            .addComponent(queue1DroppedValueLabel)
                                            .addComponent(queue1ReceivedValueLabel)))
                                    .addGroup(layout.createSequentialGroup()
                                        .addComponent(jLabel15)
                                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                        .addComponent(queue1OccupancyValueLabel))
                                    .addGroup(layout.createSequentialGroup()
                                        .addGap(12, 12, 12)
                                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                            .addComponent(queue1DRRWeightSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                                            .addGroup(layout.createSequentialGroup()
                                                .addGap(44, 44, 44)
                                                .addComponent(queue1DRRWeightSliderValue))))))
                            .addGroup(layout.createSequentialGroup()
                                .addGap(45, 45, 45)
                                .addComponent(jLabel4)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addComponent(jLabel5))))
                    .addGroup(layout.createSequentialGroup()
                        .addContainerGap()
                        .addComponent(queue2ReceivedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue2DroppedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue2OccupancyPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addGroup(layout.createSequentialGroup()
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                    .addGroup(layout.createSequentialGroup()
                                        .addGap(52, 52, 52)
                                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                                            .addComponent(jLabel18)
                                            .addComponent(jLabel19))
                                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                            .addComponent(queue2DroppedValueLabel)
                                            .addComponent(queue2ReceivedValueLabel)))
                                    .addGroup(layout.createSequentialGroup()
                                        .addComponent(jLabel20)
                                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                        .addComponent(queue2OccupancyValueLabel))))
                            .addGroup(layout.createSequentialGroup()
                                .addGap(25, 25, 25)
                                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                    .addComponent(queue2DRRWeightSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                                    .addGroup(layout.createSequentialGroup()
                                        .addGap(44, 44, 44)
                                        .addComponent(queue2DRRWeightSliderValue))))
                            .addGroup(layout.createSequentialGroup()
                                .addGap(48, 48, 48)
                                .addComponent(jLabel6)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addComponent(jLabel7))))
                    .addGroup(layout.createSequentialGroup()
                        .addContainerGap()
                        .addComponent(queue3ReceivedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue3DroppedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue3OccupancyPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addGroup(layout.createSequentialGroup()
                                .addGap(52, 52, 52)
                                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                                    .addComponent(jLabel21)
                                    .addComponent(jLabel22))
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                    .addComponent(queue3ReceivedValueLabel)
                                    .addComponent(queue3DroppedValueLabel)))
                            .addGroup(layout.createSequentialGroup()
                                .addComponent(jLabel23)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addComponent(queue3OccupancyValueLabel))
                            .addGroup(layout.createSequentialGroup()
                                .addGap(15, 15, 15)
                                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                    .addComponent(queue3DRRWeightSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                                    .addGroup(layout.createSequentialGroup()
                                        .addGap(44, 44, 44)
                                        .addComponent(queue3DRRWeightSliderValue))))
                            .addGroup(layout.createSequentialGroup()
                                .addGap(38, 38, 38)
                                .addComponent(jLabel9)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addComponent(jLabel8))))
                    .addGroup(layout.createSequentialGroup()
                        .addContainerGap()
                        .addComponent(queue4ReceivedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue4DroppedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue4OccupancyPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addGroup(layout.createSequentialGroup()
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                    .addGroup(layout.createSequentialGroup()
                                        .addGap(52, 52, 52)
                                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                                            .addComponent(jLabel24)
                                            .addComponent(jLabel25))
                                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                                            .addComponent(queue4DroppedValueLabel)
                                            .addComponent(queue4ReceivedValueLabel)))
                                    .addGroup(layout.createSequentialGroup()
                                        .addComponent(jLabel26)
                                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                        .addComponent(queue4OccupancyValueLabel))
                                    .addGroup(layout.createSequentialGroup()
                                        .addGap(44, 44, 44)
                                        .addComponent(queue4DRRWeightSliderValue))))
                            .addGroup(layout.createSequentialGroup()
                                .addGap(52, 52, 52)
                                .addComponent(jLabel11)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addComponent(jLabel10))
                            .addGroup(layout.createSequentialGroup()
                                .addGap(30, 30, 30)
                                .addComponent(queue1DRRWeightSlider3, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))))
                    .addGroup(layout.createSequentialGroup()
                        .addContainerGap()
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING, false)
                            .addGroup(javax.swing.GroupLayout.Alignment.LEADING, layout.createSequentialGroup()
                                .addComponent(quantumSliderLabel)
                                .addGap(18, 18, 18)
                                .addComponent(quantumSlider, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE))
                            .addGroup(javax.swing.GroupLayout.Alignment.LEADING, layout.createSequentialGroup()
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addComponent(slowFactorSliderLabel)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addComponent(slowFactorSlider, javax.swing.GroupLayout.PREFERRED_SIZE, 494, javax.swing.GroupLayout.PREFERRED_SIZE))))
                    .addGroup(layout.createSequentialGroup()
                        .addGap(309, 309, 309)
                        .addComponent(slowFactorSliderValueLabel))
                    .addGroup(layout.createSequentialGroup()
                        .addGap(303, 303, 303)
                        .addComponent(quantumSliderValueLabel)
                        .addGap(245, 245, 245)
                        .addComponent(resetStatsButton)))
                .addContainerGap())
        );
        layout.setVerticalGroup(
            layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
            .addGroup(layout.createSequentialGroup()
                .addContainerGap()
                .addComponent(jLabel1)
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addComponent(jSeparator1, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addGroup(layout.createSequentialGroup()
                        .addGap(36, 36, 36)
                        .addComponent(quantumSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                    .addGroup(layout.createSequentialGroup()
                        .addGap(55, 55, 55)
                        .addComponent(quantumSliderLabel)))
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addGroup(layout.createSequentialGroup()
                        .addComponent(quantumSliderValueLabel)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                            .addGroup(layout.createSequentialGroup()
                                .addGap(12, 12, 12)
                                .addComponent(slowFactorSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                                .addComponent(slowFactorSliderValueLabel))
                            .addGroup(layout.createSequentialGroup()
                                .addGap(30, 30, 30)
                                .addComponent(slowFactorSliderLabel))))
                    .addComponent(resetStatsButton))
                .addGap(42, 42, 42)
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING, false)
                    .addGroup(layout.createSequentialGroup()
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                            .addComponent(queue0ReceivedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                            .addComponent(queue0DroppedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                            .addComponent(queue0OccupancyPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                        .addGap(6, 6, 6))
                    .addGroup(layout.createSequentialGroup()
                        .addGap(22, 22, 22)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel3)
                            .addComponent(jLabel2))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue0DRRWeightSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue0DRRWeightSliderValue)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel12)
                            .addComponent(queue0ReceivedValueLabel))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel13)
                            .addComponent(queue0DroppedValueLabel))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel14)
                            .addComponent(queue0OccupancyValueLabel))
                        .addGap(29, 29, 29)))
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING, false)
                    .addGroup(layout.createSequentialGroup()
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                            .addComponent(queue1ReceivedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                            .addComponent(queue1DroppedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                            .addComponent(queue1OccupancyPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED))
                    .addGroup(layout.createSequentialGroup()
                        .addGap(16, 16, 16)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel5)
                            .addComponent(jLabel4))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.UNRELATED)
                        .addComponent(queue1DRRWeightSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue1DRRWeightSliderValue)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel17)
                            .addComponent(queue1ReceivedValueLabel))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel16)
                            .addComponent(queue1DroppedValueLabel))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel15)
                            .addComponent(queue1OccupancyValueLabel))
                        .addGap(15, 15, 15)))
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING, false)
                    .addGroup(layout.createSequentialGroup()
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                            .addComponent(queue2ReceivedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                            .addComponent(queue2OccupancyPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                            .addComponent(queue2DroppedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED))
                    .addGroup(layout.createSequentialGroup()
                        .addGap(28, 28, 28)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel7)
                            .addComponent(jLabel6))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue2DRRWeightSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue2DRRWeightSliderValue)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED, javax.swing.GroupLayout.DEFAULT_SIZE, Short.MAX_VALUE)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel18)
                            .addComponent(queue2ReceivedValueLabel))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel19)
                            .addComponent(queue2DroppedValueLabel))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel20)
                            .addComponent(queue2OccupancyValueLabel))
                        .addGap(20, 20, 20)))
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                        .addComponent(queue3ReceivedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addComponent(queue3OccupancyPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addComponent(queue3DroppedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                    .addGroup(layout.createSequentialGroup()
                        .addGap(16, 16, 16)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel8)
                            .addComponent(jLabel9))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue3DRRWeightSlider, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue3DRRWeightSliderValue)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel21)
                            .addComponent(queue3ReceivedValueLabel))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel22)
                            .addComponent(queue3DroppedValueLabel))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel23)
                            .addComponent(queue3OccupancyValueLabel))))
                .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.LEADING)
                    .addGroup(layout.createSequentialGroup()
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.TRAILING)
                            .addComponent(queue4ReceivedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                            .addComponent(queue4DroppedPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                            .addComponent(queue4OccupancyPanel, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE))
                        .addContainerGap(28, Short.MAX_VALUE))
                    .addGroup(layout.createSequentialGroup()
                        .addGap(28, 28, 28)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel10)
                            .addComponent(jLabel11))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.UNRELATED)
                        .addComponent(queue1DRRWeightSlider3, javax.swing.GroupLayout.PREFERRED_SIZE, javax.swing.GroupLayout.DEFAULT_SIZE, javax.swing.GroupLayout.PREFERRED_SIZE)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addComponent(queue4DRRWeightSliderValue)
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED, 10, Short.MAX_VALUE)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel24)
                            .addComponent(queue4ReceivedValueLabel))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel25)
                            .addComponent(queue4DroppedValueLabel))
                        .addPreferredGap(javax.swing.LayoutStyle.ComponentPlacement.RELATED)
                        .addGroup(layout.createParallelGroup(javax.swing.GroupLayout.Alignment.BASELINE)
                            .addComponent(jLabel26)
                            .addComponent(queue4OccupancyValueLabel))
                        .addGap(47, 47, 47))))
        );
    }// </editor-fold>//GEN-END:initComponents

private void resetStatsButtonActionPerformed(java.awt.event.ActionEvent evt) {//GEN-FIRST:event_resetStatsButtonActionPerformed
    drrStatsRegTableModel.clearAll();
    for(int i=0; i<statsCollection.length; i++) {
        statsCollection[i].reset();
        regTableModel.setValueAt(new Integer(0), i, RegTableModel.VALUE_COL);
    }
}//GEN-LAST:event_resetStatsButtonActionPerformed

    public void clearTimer(){
        this.timer.removeActionListener(timerActionListener);
    }

    // Variables declaration - do not modify//GEN-BEGIN:variables
    private javax.swing.ButtonGroup buttonGroup1;
    private javax.swing.ButtonGroup buttonGroup2;
    private javax.swing.ButtonGroup buttonGroup3;
    private javax.swing.ButtonGroup buttonGroup4;
    private javax.swing.ButtonGroup buttonGroup5;
    private javax.swing.ButtonGroup buttonGroup6;
    private javax.swing.JLabel jLabel1;
    private javax.swing.JLabel jLabel10;
    private javax.swing.JLabel jLabel11;
    private javax.swing.JLabel jLabel12;
    private javax.swing.JLabel jLabel13;
    private javax.swing.JLabel jLabel14;
    private javax.swing.JLabel jLabel15;
    private javax.swing.JLabel jLabel16;
    private javax.swing.JLabel jLabel17;
    private javax.swing.JLabel jLabel18;
    private javax.swing.JLabel jLabel19;
    private javax.swing.JLabel jLabel2;
    private javax.swing.JLabel jLabel20;
    private javax.swing.JLabel jLabel21;
    private javax.swing.JLabel jLabel22;
    private javax.swing.JLabel jLabel23;
    private javax.swing.JLabel jLabel24;
    private javax.swing.JLabel jLabel25;
    private javax.swing.JLabel jLabel26;
    private javax.swing.JLabel jLabel3;
    private javax.swing.JLabel jLabel4;
    private javax.swing.JLabel jLabel5;
    private javax.swing.JLabel jLabel6;
    private javax.swing.JLabel jLabel7;
    private javax.swing.JLabel jLabel8;
    private javax.swing.JLabel jLabel9;
    private javax.swing.JSeparator jSeparator1;
    private javax.swing.JSlider quantumSlider;
    private javax.swing.JLabel quantumSliderLabel;
    private javax.swing.JLabel quantumSliderValueLabel;
    private javax.swing.JSlider queue0DRRWeightSlider;
    private javax.swing.JLabel queue0DRRWeightSliderValue;
    private javax.swing.JPanel queue0DroppedPanel;
    private javax.swing.JLabel queue0DroppedValueLabel;
    private javax.swing.JPanel queue0OccupancyPanel;
    private javax.swing.JLabel queue0OccupancyValueLabel;
    private javax.swing.JPanel queue0ReceivedPanel;
    private javax.swing.JLabel queue0ReceivedValueLabel;
    private javax.swing.JSlider queue1DRRWeightSlider;
    private javax.swing.JSlider queue1DRRWeightSlider3;
    private javax.swing.JLabel queue1DRRWeightSliderValue;
    private javax.swing.JPanel queue1DroppedPanel;
    private javax.swing.JLabel queue1DroppedValueLabel;
    private javax.swing.JPanel queue1OccupancyPanel;
    private javax.swing.JLabel queue1OccupancyValueLabel;
    private javax.swing.JPanel queue1ReceivedPanel;
    private javax.swing.JLabel queue1ReceivedValueLabel;
    private javax.swing.JSlider queue2DRRWeightSlider;
    private javax.swing.JLabel queue2DRRWeightSliderValue;
    private javax.swing.JPanel queue2DroppedPanel;
    private javax.swing.JLabel queue2DroppedValueLabel;
    private javax.swing.JPanel queue2OccupancyPanel;
    private javax.swing.JLabel queue2OccupancyValueLabel;
    private javax.swing.JPanel queue2ReceivedPanel;
    private javax.swing.JLabel queue2ReceivedValueLabel;
    private javax.swing.JSlider queue3DRRWeightSlider;
    private javax.swing.JLabel queue3DRRWeightSliderValue;
    private javax.swing.JPanel queue3DroppedPanel;
    private javax.swing.JLabel queue3DroppedValueLabel;
    private javax.swing.JPanel queue3OccupancyPanel;
    private javax.swing.JLabel queue3OccupancyValueLabel;
    private javax.swing.JPanel queue3ReceivedPanel;
    private javax.swing.JLabel queue3ReceivedValueLabel;
    private javax.swing.JLabel queue4DRRWeightSliderValue;
    private javax.swing.JPanel queue4DroppedPanel;
    private javax.swing.JLabel queue4DroppedValueLabel;
    private javax.swing.JPanel queue4OccupancyPanel;
    private javax.swing.JLabel queue4OccupancyValueLabel;
    private javax.swing.JPanel queue4ReceivedPanel;
    private javax.swing.JLabel queue4ReceivedValueLabel;
    private javax.swing.JButton resetStatsButton;
    private javax.swing.JSlider slowFactorSlider;
    private javax.swing.JLabel slowFactorSliderLabel;
    private javax.swing.JLabel slowFactorSliderValueLabel;
    // End of variables declaration//GEN-END:variables

}
